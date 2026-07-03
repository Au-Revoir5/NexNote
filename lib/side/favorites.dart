import 'package:flutter/material.dart';
import 'package:nexnote/backend/file_opener.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/thumbnail/note_thumbnail.dart';
import '../backend/thumbnail/note_thumbnail_cache.dart';
import '../backend/thumbnail/note_thumbnail_generator.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'dart:async';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class FavoritesPage extends StatefulWidget {
  final bool showAppBar;

  const FavoritesPage({super.key, this.showAppBar = true});

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String? _copiedNoteId;
  Timer? _copyResetTimer;
  final _supabase = Supabase.instance.client;
  String sortBy = "Last Edited (Recent)";
  bool isGridView = false;
  bool _isLoading = true;
  List<Map<String, dynamic>> _favoriteNotes = [];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }
  bool _isOwner(Map<String, dynamic> note) {
    final currentUserId = _supabase.auth.currentUser?.id;
    return currentUserId != null && note['owner_id'] == currentUserId;
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('favorites')
          .select('note_id, created_at, notes(*)')
          .eq('user_id', user.id);

      final favorites = (response as List).map((fav) {
        final note = fav['notes'];
        return {
          'favorite_id': fav['note_id'],
          'id': note['id'],
          'title': note['title'],
          'file_url': note['file_url'],
          'file_type': note['file_type'],
          'tags': note['tags'],
          'is_public': note['is_public'],
          'updated_at': note['updated_at'],
          'created_at': note['created_at'],
          'owner_id': note['user_id'],
        };
      }).toList();

      setState(() {
        _favoriteNotes = favorites;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading favorites: $e')),
        );
      }
    }
  }

  Future<void> _removeFavorite(String noteId) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('note_id', noteId);

      await _loadFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing favorite: $e')),
        );
      }
    }
  }

  Future<void> _deleteNote(String noteId, String fileUrl) async {
    try {
      final fileName = fileUrl.split('/').last;
      await _supabase.storage.from('notes').remove([fileName]);
      await _supabase.from('notes').delete().eq('id', noteId);
      await _loadFavorites();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting note: $e')),
        );
      }
    }
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Unknown';
    
    // Supabase returns UTC timestamps without 'Z', so we need to parse as UTC explicitly
    final dateTime = DateTime.parse(timestamp + 'Z').toLocal();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} year${(difference.inDays / 365).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final textScale = width < 360 ? 0.9 : 1.0;
    final iconSize = width < 360 ? 20.0 : 24.0;
    final padding = width < 360 ? 12.0 : 16.0;

    List<Map<String, dynamic>> sortedItems = List.from(_favoriteNotes);
    _sortItems(sortedItems);

    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: widget.showAppBar
          ? AppBar(
              backgroundColor: kDarkSurface,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                "My Favorites",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18 * textScale,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: _showSortOptions,
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  sortBy,
                                  style: TextStyle(color: Colors.white70, fontSize: 16 * textScale),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isGridView ? Icons.grid_view : Icons.list,
                          color: Colors.white70,
                          size: iconSize,
                        ),
                        onPressed: () {
                          setState(() {
                            isGridView = !isGridView;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: _favoriteNotes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.star_border, size: 64, color: Colors.grey[600]),
                              const SizedBox(height: 16),
                              Text('No favorites yet', style: TextStyle(color: Colors.grey[400], fontSize: 16)),
                              const SizedBox(height: 8),
                              Text(
                                'Tap the star icon on any note to add it here',
                                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          color: kPrimaryColor,
                          onRefresh: _loadFavorites,
                          child: isGridView
                              ? _buildGridView(sortedItems, width)
                              : _buildListView(sortedItems, textScale, iconSize),
                        ),
                ),
              ],
            ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sortOption("Last Edited (Recent)"),
                _sortOption("Last Edited (Oldest)"),
                _sortOption("Alphabetical"),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sortItems(List<Map<String, dynamic>> items) {
    switch (sortBy) {
      case "Last Edited (Recent)":
        items.sort((a, b) => DateTime.parse(b['updated_at']).compareTo(DateTime.parse(a['updated_at'])));
        break;
      case "Last Edited (Oldest)":
        items.sort((a, b) => DateTime.parse(a['updated_at']).compareTo(DateTime.parse(b['updated_at'])));
        break;
      case "Alphabetical":
        items.sort((a, b) => a['title'].compareTo(b['title']));
        break;
    }
  }

  Widget _sortOption(String option) {
    final isSelected = sortBy == option;
    return ListTile(
      title: Text(option, style: TextStyle(color: isSelected ? kPrimaryColor : Colors.white, fontSize: 16)),
      trailing: isSelected ? const Icon(Icons.check, color: kPrimaryColor) : null,
      onTap: () {
        setState(() {
          sortBy = option;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> items, double width) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final note = items[index];
        return FavoriteGridItemWidget(
          note: note,
          timeAgo: _getTimeAgo(note['updated_at']),
          onTap: () {
            FileOpener.openFile(
              context,
              note['file_url'],
              '${note['title']}.${note['file_type']}',
            );
          },
          onMenuTap: () => _showItemMenu(note),
        );
      },
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> items, double textScale, double iconSize) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final note = items[index];
        return FavoriteItemWidget(
          note: note,
          timeAgo: _getTimeAgo(note['updated_at']),
          onTap: () {
            FileOpener.openFile(
              context,
              note['file_url'],
              '${note['title']}.${note['file_type']}',
            );
          },
          onMenuTap: () => _showItemMenu(note),
          textScale: textScale,
          iconSize: iconSize,
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : Colors.white,
      ),
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


  void _showItemMenu(Map<String, dynamic> note) {
  final isOwner = _isOwner(note);

  showModalBottomSheet(
    backgroundColor: kCardColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isOwner)
              _buildOption(context, Icons.edit, "Edit note", () {
                Navigator.pop(context);
                _showEditDialog(note);
              }),

            _buildOption(context, Icons.share, "Share", () async {
              Navigator.pop(context);

              try {
                final supabase = Supabase.instance.client;

                final uri = Uri.parse(note['file_url']);
                final segments = uri.pathSegments;

                final bucketIndex = segments.indexOf('notes');
                if (bucketIndex == -1) throw Exception('Invalid file URL');

                final storagePath =
                    segments.sublist(bucketIndex + 1).join('/');

                final signedUrl = await supabase.storage
                    .from('notes')
                    .createSignedUrl(storagePath, 60 * 60);

                await Share.share(
                  '📄 ${note['title']}\n\n$signedUrl',
                  subject: note['title'],
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to share note: $e')),
                );
              }
            }),

            _buildOption(
              context,
              _copiedNoteId == note['id'] ? Icons.check : Icons.link,
              _copiedNoteId == note['id'] ? "Copied" : "Copy link",
              () async {
                try {
                  final uri = Uri.parse(note['file_url']);
                  final segments = uri.pathSegments;

                  final bucketIndex = segments.indexOf('notes');
                  if (bucketIndex == -1) throw Exception('Invalid file URL');

                  final storagePath =
                      segments.sublist(bucketIndex + 1).join('/');

                  final signedUrl = await _supabase.storage
                      .from('notes')
                      .createSignedUrl(storagePath, 60 * 60);

                  await Clipboard.setData(
                    ClipboardData(text: signedUrl),
                  );

                  setSheetState(() {
                    _copiedNoteId = note['id'];
                  });

                  HapticFeedback.lightImpact();

                  _copyResetTimer?.cancel();
                  _copyResetTimer = Timer(const Duration(seconds: 5), () {
                    if (!mounted) return;
                    setSheetState(() {
                      _copiedNoteId = null;
                    });
                  });
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to copy link: $e')),
                  );
                }
              },
            ),

            _buildOption(
              context,
              Icons.star_border,
              "Remove from Favorites",
              () {
                Navigator.pop(context);
                _removeFavorite(note['id']);
              },
            ),

            const Divider(color: Colors.grey),

            if (isOwner)
              _buildOption(
                context,
                Icons.delete,
                "Delete",
                () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(note);
                },
                isDestructive: true,
              )
            else
              _buildOption(
                context,
                Icons.report_outlined,
                "Report note",
                () {
                  Navigator.pop(context);
                  // TODO: wire up reporting flow if you have one
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted')),
                  );
                },
                isDestructive: true,
              ),
          ],
        ),
      ),
    ),
  );
}

  void _showEditDialog(Map<String, dynamic> note) {
    final TextEditingController titleController =
    TextEditingController(text: note['title']);

    final TextEditingController descController =
        TextEditingController(text: note['description'] ?? '');

    final TextEditingController tagController = TextEditingController();

    List<String> editableTags =
        note['tags'] != null ? List<String>.from(note['tags']) : [];


    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: kCardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Edit Note',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title input
                const Text(
                  'Title',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: kDarkSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: titleController,
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
                
                // Description input
                const Text(
                  'Description',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: kDarkSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: descController,
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
                
                // Tags section
                const Text(
                  'Tags',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
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
                        onPressed: () {
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
                
                // Display tags
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
                              onTap: () {
                                setDialogState(() {
                                  editableTags.remove(tag);
                                });
                              },
                              child: Icon(
                                Icons.close,
                                color: Colors.grey[400],
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey, fontSize: 15),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  final supabase = Supabase.instance.client;
                  await supabase
                      .from('notes')
                      .update({
                        'title': titleController.text.trim(),
                        'description': descController.text.trim().isEmpty ? null : descController.text.trim(),
                        'tags': editableTags,
                      })
                      .eq('id', note['id']);
                  
                  if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _loadFavorites();
                } catch (e) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error updating note: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
  void _showDeleteConfirmation(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Delete Note', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Are you sure you want to delete this note? This action cannot be undone.',
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
              _deleteNote(note['id'], note['file_url']);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// Grid Item Widget with PDF Preview
class FavoriteGridItemWidget extends StatefulWidget {
  final Map<String, dynamic> note;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const FavoriteGridItemWidget({
    super.key,
    required this.note,
    required this.timeAgo,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  State<FavoriteGridItemWidget> createState() => _FavoriteGridItemWidgetState();
}

class _FavoriteGridItemWidgetState extends State<FavoriteGridItemWidget> {


  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _getColor().withOpacity(0.3),
                            _getColor().withOpacity(0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    _buildPreview(),
                    if (widget.note['is_public'] == true)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.public, color: Colors.white, size: 10),
                              SizedBox(width: 3),
                              Text('Public', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _getColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(_getIcon(), color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.note['title'] ?? 'Untitled',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: widget.onMenuTap,
                        child: Icon(Icons.more_vert, color: Colors.grey[400], size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text("Last edited ${widget.timeAgo}", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreview() {
    return NoteThumbnailWithCache(
      noteId: widget.note['id'],
      fileUrl: widget.note['file_url'],
      fileType: widget.note['file_type'],
    );
  }


  Color _getColor() {
    final fileType = widget.note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Colors.red[300]!;
      case 'docx':
        return Colors.blue[300]!;
      default:
        return kPrimaryColor;
    }
  }

  IconData _getIcon() {
    final fileType = widget.note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

// List Item Widget
class FavoriteItemWidget extends StatelessWidget {
  final Map<String, dynamic> note;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final double textScale;
  final double iconSize;

  const FavoriteItemWidget({
    super.key,
    required this.note,
    required this.timeAgo,
    required this.onTap,
    required this.onMenuTap,
    required this.textScale,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _getColor().withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[700]!, width: 1),
                ),
                child: Icon(_getIcon(), color: _getColor(), size: iconSize + 4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note['title'] ?? 'Untitled',
                      style: TextStyle(color: Colors.white, fontSize: 16 * textScale, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 4),
                    Text("Last edited $timeAgo", style: TextStyle(color: Colors.grey[400], fontSize: 13 * textScale)),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert, color: Colors.grey[400], size: iconSize),
                onPressed: onMenuTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    final fileType = note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Colors.red[300]!;
      case 'docx':
        return Colors.blue[300]!;
      default:
        return kPrimaryColor;
    }
  }

  IconData _getIcon() {
    final fileType = note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

class NoteThumbnailWithCache extends StatefulWidget {
  final String noteId;
  final String fileUrl;
  final String fileType;

  const NoteThumbnailWithCache({
    super.key,
    required this.noteId,
    required this.fileUrl,
    required this.fileType,
  });

  @override
  State<NoteThumbnailWithCache> createState() =>
      _NoteThumbnailWithCacheState();
}

class _NoteThumbnailWithCacheState extends State<NoteThumbnailWithCache> {
  Uint8List? _pdf;
  String? _docx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _pdf = NoteThumbnailCache.getPdf(widget.noteId);
    _docx = NoteThumbnailCache.getDocx(widget.noteId);

    if (_pdf != null || _docx != null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      if (widget.fileType == 'pdf') {
        final bytes = await generatePdfThumbnail(widget.fileUrl);
        if (!mounted) return;

        NoteThumbnailCache.setPdf(widget.noteId, bytes);
        _pdf = bytes;
      } else if (widget.fileType == 'docx') {
        final text = await generateDocxPreview(widget.fileUrl);
        if (!mounted) return;

        NoteThumbnailCache.setDocx(widget.noteId, text);
        _docx = text;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Thumbnail load error: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    return NoteThumbnail(
      noteId: widget.noteId,
      fileType: widget.fileType,
      pdfThumbnail: _pdf,
      docxPreviewText: _docx,
    );
  }
}
