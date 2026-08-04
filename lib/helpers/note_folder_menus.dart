import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main/my_notes.dart' show kCardColor, kDarkSurface, kPrimaryColor;
import 'thumbnail/note_thumbnail_cache.dart';

/// Single source of truth for note and folder actions (favorite, share,
/// copy link, edit, delete/unsave, rename/delete folder) and for the
/// "..." bottom sheets that expose them. Every kebab menu in the app -
/// NoteItem's list tiles, FoldersPage's grid tiles, and NotesPage's
/// folder cards - calls into this file instead of keeping its own copy.

// ---------------------------------------------------------------------
// NOTE ACTIONS (DB ops + dialogs, no page-specific state required)
// ---------------------------------------------------------------------

Future<void> toggleNoteFavorite(
  BuildContext context, {
  required String noteId,
  required bool isFavorite,
}) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return;

  try {
    if (isFavorite) {
      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('note_id', noteId);
    } else {
      await supabase.from('favorites').insert({
        'user_id': user.id,
        'note_id': noteId,
      });
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite: $e')),
      );
    }
    rethrow;
  }
}

Future<void> shareNote(
  BuildContext context, {
  required String title,
  required String fileUrl,
}) async {
  try {
    final supabase = Supabase.instance.client;
    final uri = Uri.parse(fileUrl);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('notes');
    if (bucketIndex == -1) throw Exception('Invalid file URL');
    final storagePath = segments.sublist(bucketIndex + 1).join('/');

    final signedUrl = await supabase.storage
        .from('notes')
        .createSignedUrl(storagePath, 60 * 60);

    await Share.share('📄 $title\n\n$signedUrl', subject: title);
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to share note: $e')));
  }
}

Future<void> copyNoteLink(BuildContext context, {required String fileUrl}) async {
  try {
    final supabase = Supabase.instance.client;
    final uri = Uri.parse(fileUrl);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf('notes');
    if (bucketIndex == -1) throw Exception('Invalid file URL');
    final storagePath = segments.sublist(bucketIndex + 1).join('/');

    final signedUrl = await supabase.storage
        .from('notes')
        .createSignedUrl(storagePath, 60 * 60);

    await Clipboard.setData(ClipboardData(text: signedUrl));

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Secure link copied (1 hour valid)')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to copy link: $e')));
  }
}

Future<void> deleteNoteToTrash(
  BuildContext context, {
  required String noteId,
}) async {
  try {
    final supabase = Supabase.instance.client;
    await supabase
        .from('notes')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'delete_expires_at': DateTime.now()
              .toUtc()
              .add(const Duration(days: 10))
              .toIso8601String(),
        })
        .eq('id', noteId)
        .eq('user_id', supabase.auth.currentUser!.id);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Note moved to trash (deleted in 10 days)')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
    rethrow;
  }
}

Future<void> unsaveNote(BuildContext context, {required String noteId}) async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return;
  try {
    await Supabase.instance.client
        .from('saved_notes')
        .delete()
        .eq('user_id', user.id)
        .eq('note_id', noteId);

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Removed from saved notes')));
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to unsave note: $e')));
    rethrow;
  }
}

void confirmDeleteNote(BuildContext context, {required VoidCallback onConfirmed}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: kCardColor,
      title: const Text('Delete Note', style: TextStyle(color: Colors.white)),
      content: const Text(
        'Are you sure you want to delete this note? This note will be deleted permanently after 10 days.',
        style: TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onConfirmed();
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

/// Extracts the storage path (everything after the bucket segment) from a
/// Supabase public/signed file URL. Returns null if it can't be parsed.
String? _storagePathFromUrl(String fileUrl, {String bucket = 'notes'}) {
  try {
    final uri = Uri.parse(fileUrl);
    final segments = uri.pathSegments;
    final bucketIndex = segments.indexOf(bucket);
    if (bucketIndex == -1) return null;
    return segments.sublist(bucketIndex + 1).join('/');
  } catch (_) {
    return null;
  }
}

/// Uploads [newFile] to storage under the current user's folder, returning
/// the new public URL and the file extension used. Does not touch the DB.
Future<({String url, String ext})> _uploadReplacementFile(File newFile) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) throw Exception('User not authenticated');

  final ext = newFile.path.split('.').last.toLowerCase();
  final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
  final filePath = '${user.id}/$fileName';

  await supabase.storage.from('notes').upload(filePath, newFile);
  final url = supabase.storage.from('notes').getPublicUrl(filePath);

  return (url: url, ext: ext);
}

void showEditNoteDialog(
  BuildContext context, {
  required String noteId,
  required String title,
  String? description,
  required List<String> tags,
  required String fileUrl,
  String? fileType,
  required VoidCallback onSaved,
}) {
  final titleController = TextEditingController(text: title);
  final descController = TextEditingController(text: description ?? '');
  final tagController = TextEditingController();
  List<String> editableTags = List<String>.from(tags);

  File? selectedNewFile;
  String? selectedNewFileName;
  bool isSaving = false;

  showDialog(
    context: context,
    barrierDismissible: !isSaving,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> pickReplacementFile() async {
          try {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['pdf', 'docx'],
            );
            if (result != null && result.files.single.path != null) {
              setDialogState(() {
                selectedNewFile = File(result.files.single.path!);
                selectedNewFileName = result.files.single.name;
              });
            }
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error picking file: $e')),
            );
          }
        }

        Future<void> save() async {
          if (titleController.text.trim().isEmpty) return;

          setDialogState(() => isSaving = true);

          try {
            final updates = <String, dynamic>{
              'title': titleController.text.trim(),
              'description': descController.text.trim().isEmpty
                  ? null
                  : descController.text.trim(),
              'tags': editableTags,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            };

            String? oldStoragePath;

            // If a replacement file was picked, upload it first and point
            // the note at the new file. The old object is deleted only
            // after the DB row updates successfully, so a failed update
            // never leaves the note pointing at a missing file.
            if (selectedNewFile != null) {
              oldStoragePath = _storagePathFromUrl(fileUrl);
              final uploaded = await _uploadReplacementFile(selectedNewFile!);
              updates['file_url'] = uploaded.url;
              updates['file_type'] = uploaded.ext;
            }

            await Supabase.instance.client
                .from('notes')
                .update(updates)
                .eq('id', noteId);

            if (selectedNewFile != null && oldStoragePath != null) {
              try {
                await Supabase.instance.client.storage
                    .from('notes')
                    .remove([oldStoragePath]);
              } catch (_) {
                // Old file cleanup is best-effort; the note itself already
                // points at the new file, so this failing isn't critical.
              }
            }

            // The cached thumbnail/preview is keyed by noteId and was built
            // from the old file, so it's stale as soon as the file changes.
            // Drop it here; the grid will regenerate one from the new file.
            if (selectedNewFile != null) {
              NoteThumbnailCache.remove(noteId);
            }

            if (!context.mounted) return;
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Note updated successfully'),
                backgroundColor: Colors.green,
              ),
            );
            onSaved();
          } catch (e) {
            setDialogState(() => isSaving = false);
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating note: $e'), backgroundColor: Colors.red),
            );
          }
        }

        return AlertDialog(
          backgroundColor: kCardColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Edit Note',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: kDarkSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: titleController,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Enter title...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Description', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: kDarkSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: descController,
                    enabled: !isSaving,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Add a description...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Tags', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: kDarkSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextField(
                          controller: tagController,
                          enabled: !isSaving,
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                          decoration: const InputDecoration(
                            hintText: 'Add a tag...',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                          onSubmitted: (value) {
                            final trimmed = value.trim().toLowerCase();
                            if (trimmed.isNotEmpty && !editableTags.contains(trimmed)) {
                              setDialogState(() {
                                editableTags.add(trimmed);
                                tagController.clear();
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: kPrimaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add, color: Colors.white, size: 20),
                        onPressed: isSaving
                            ? null
                            : () {
                                final trimmed = tagController.text.trim().toLowerCase();
                                if (trimmed.isNotEmpty && !editableTags.contains(trimmed)) {
                                  setDialogState(() {
                                    editableTags.add(trimmed);
                                    tagController.clear();
                                  });
                                }
                              },
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (editableTags.isNotEmpty)
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: editableTags.map((tag) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: kDarkSurface,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: kPrimaryColor.withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: isSaving
                                  ? null
                                  : () => setDialogState(() => editableTags.remove(tag)),
                              child: Icon(Icons.close, color: Colors.grey[400], size: 14),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 16),
                const Text('File', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: isSaving ? null : pickReplacementFile,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: kDarkSurface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selectedNewFile != null
                            ? kPrimaryColor
                            : Colors.grey.withOpacity(0.3),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selectedNewFile != null ? Icons.check_circle : Icons.upload_file,
                          color: selectedNewFile != null ? kPrimaryColor : Colors.grey,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            selectedNewFile != null
                                ? selectedNewFileName ?? 'New file selected'
                                : 'Replace file (current: ${(fileType ?? '').toUpperCase()})',
                            style: TextStyle(
                              color: selectedNewFile != null ? Colors.white : Colors.grey,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selectedNewFile != null)
                          GestureDetector(
                            onTap: isSaving
                                ? null
                                : () => setDialogState(() {
                                      selectedNewFile = null;
                                      selectedNewFileName = null;
                                    }),
                            child: Icon(Icons.close, color: Colors.grey[400], size: 18),
                          ),
                      ],
                    ),
                  ),
                ),
                if (selectedNewFile != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Saving will replace the existing file (PDF/DOCX only).',
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 15)),
            ),
            ElevatedButton(
              onPressed: isSaving ? null : save,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                disabledBackgroundColor: kPrimaryColor.withOpacity(0.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: isSaving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Save', style: TextStyle(color: Colors.white, fontSize: 15)),
            ),
          ],
        );
      },
    ),
  );
}

Widget _sheetAction(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  return ListTile(
    leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white),
    title: Text(
      label,
      style: TextStyle(
        color: isDestructive ? Colors.red : Colors.white,
        fontWeight: FontWeight.w500,
      ),
    ),
    onTap: onTap,
  );
}

/// The one note "..." menu used everywhere: NoteItem list tiles and
/// FoldersPage's grid tiles.
Future<void> showNoteOptionsMenu(
  BuildContext context, {
  required String noteId,
  required String title,
  String? description,
  required String fileUrl,
  String? fileType,
  required List<String> tags,
  required bool isOwned,
  required bool isFavorite,
  bool showFavoriteAction = true,
  required VoidCallback onMoveToFolder,
  required VoidCallback onRefresh,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: kCardColor,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            if (isOwned)
              _sheetAction(
                context,
                icon: Icons.edit,
                label: 'Edit note',
                onTap: () {
                  Navigator.pop(context);
                  showEditNoteDialog(
                    context,
                    noteId: noteId,
                    title: title,
                    description: description,
                    tags: tags,
                    fileUrl: fileUrl,
                    fileType: fileType,
                    onSaved: onRefresh,
                  );
                },
              ),
            if (showFavoriteAction)
              _sheetAction(
                context,
                icon: Icons.star_border,
                label: isFavorite ? 'Remove from starred' : 'Add to starred',
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await toggleNoteFavorite(context, noteId: noteId, isFavorite: isFavorite);
                    onRefresh();
                  } catch (_) {}
                },
              ),
            _sheetAction(
              context,
              icon: Icons.folder_open_outlined,
              label: 'Move to folder',
              onTap: () {
                Navigator.pop(context);
                onMoveToFolder();
              },
            ),
            _sheetAction(
              context,
              icon: Icons.share,
              label: 'Share',
              onTap: () {
                Navigator.pop(context);
                shareNote(context, title: title, fileUrl: fileUrl);
              },
            ),
            _sheetAction(
              context,
              icon: Icons.link,
              label: 'Copy link',
              onTap: () {
                Navigator.pop(context);
                copyNoteLink(context, fileUrl: fileUrl);
              },
            ),
            const Divider(color: Colors.grey),
            if (isOwned)
              _sheetAction(
                context,
                icon: Icons.delete_outline,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  confirmDeleteNote(
                    context,
                    onConfirmed: () async {
                      try {
                        await deleteNoteToTrash(context, noteId: noteId);
                        onRefresh();
                      } catch (_) {}
                    },
                  );
                },
              )
            else
              _sheetAction(
                context,
                icon: Icons.remove_circle_outline,
                label: 'Unsave',
                isDestructive: true,
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await unsaveNote(context, noteId: noteId);
                    onRefresh();
                  } catch (_) {}
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      );
    },
  );
}

// ---------------------------------------------------------------------
// FOLDER ACTIONS
// ---------------------------------------------------------------------

void showRenameFolderDialog(
  BuildContext context, {
  required String folderId,
  required String currentName,
  required VoidCallback onRenamed,
}) {
  final controller = TextEditingController(text: currentName);
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: kCardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Rename Folder', style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: controller,
        autofocus: true,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Folder name',
          hintStyle: const TextStyle(color: Colors.grey),
          filled: true,
          fillColor: kDarkSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            final name = controller.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(context);
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) return;
            try {
              await Supabase.instance.client
                  .from('folders')
                  .update({
                    'name': name,
                    'updated_at': DateTime.now().toUtc().toIso8601String(),
                  })
                  .eq('id', folderId)
                  .eq('user_id', user.id);
              onRenamed();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Failed to rename folder: $e')));
            }
          },
          child: const Text('Save', style: TextStyle(color: kPrimaryColor)),
        ),
      ],
    ),
  );
}

void confirmDeleteFolder(
  BuildContext context, {
  required String folderId,
  required String folderName,
  required VoidCallback onDeleted,
}) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: kCardColor,
      title: const Text('Delete Folder', style: TextStyle(color: Colors.white)),
      content: Text(
        'Delete "$folderName"? Subfolders will also be deleted. Notes inside (owned or saved) will become unfiled, not deleted.',
        style: const TextStyle(color: Colors.grey),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        TextButton(
          onPressed: () async {
            Navigator.pop(context);
            final user = Supabase.instance.client.auth.currentUser;
            if (user == null) return;
            try {
              await Supabase.instance.client
                  .from('folders')
                  .delete()
                  .eq('id', folderId)
                  .eq('user_id', user.id);
              if (context.mounted) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Folder deleted')));
              }
              onDeleted();
            } catch (e) {
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Failed to delete folder: $e')));
            }
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}

/// The one folder "..." menu, used by FoldersPage's folder tiles/grid and
/// NotesPage's dashboard folder cards.
void showFolderOptionsMenu(
  BuildContext context, {
  required String folderId,
  required String folderName,
  required VoidCallback onRenamed,
  required VoidCallback onDeleted,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: kCardColor,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _sheetAction(
            context,
            icon: Icons.drive_file_rename_outline,
            label: 'Rename',
            onTap: () {
              Navigator.pop(context);
              showRenameFolderDialog(
                context,
                folderId: folderId,
                currentName: folderName,
                onRenamed: onRenamed,
              );
            },
          ),
          const Divider(),
          _sheetAction(
            context,
            icon: Icons.delete_outline,
            label: 'Delete folder',
            isDestructive: true,
            onTap: () {
              Navigator.pop(context);
              confirmDeleteFolder(
                context,
                folderId: folderId,
                folderName: folderName,
                onDeleted: onDeleted,
              );
            },
          ),
        ],
      ),
    ),
  );
}