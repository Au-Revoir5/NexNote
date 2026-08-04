import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../side/favorites.dart';
import '../side/trash.dart';
import 'package:nexnote/helpers/file_opener.dart';
import 'add.dart';
import 'package:flutter/services.dart';
import '../helpers/note_folder_menus.dart';
import '../side/All_notes.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class NotesPage extends StatefulWidget {
  final ValueChanged<bool>? onSelectionModeChanged;
  const NotesPage({super.key, this.onSelectionModeChanged});

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _communityNotes = [];
  bool _isLoadingSaved = true;

  // ---- Recent notes (root-level dashboard, folder-agnostic) ----
  List<Map<String, dynamic>> _recentNotes = [];
  bool _isLoadingRecent = true;
  static const int _recentNotesLimit = 5;

  // ---- Recent folders (root-level dashboard preview) ----
  List<Map<String, dynamic>> _recentFolders = [];
  bool _isLoadingRecentFolders = true;
  static const int _recentFoldersLimit = 4;

  final Set<String> _selectedNoteIds = {};
  bool _selectionMode = false;

  // ---- Search ----
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _loadSavedNotes() async {
    setState(() => _isLoadingSaved = true);

    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingSaved = false);
      return;
    }

    try {
      final response = await _supabase
          .from('saved_notes')
          .select('''
          note_id,
          created_at,
          folder_id,
          notes (
            id,
            title,
            description,
            file_url,
            file_type,
            is_public,
            updated_at,
            tags,
            publisher_id,
            profiles:publisher_id ( username, avatar_url )
          )
        ''')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      // Favorites can apply to any note, owned or not, so check them here too
      final favoritesResponse = await _supabase
          .from('favorites')
          .select('note_id')
          .eq('user_id', user.id);
      final favoriteNoteIds =
          (favoritesResponse as List)
              .map((fav) => fav['note_id'] as String)
              .toSet();

      final saved =
          (response as List).where((row) => row['notes'] != null).map((row) {
            final note = row['notes'];
            return {
              'id': note['id'],
              'title': note['title'] ?? 'Untitled',
              'description': note['description'],
              'file_url': note['file_url'],
              'file_type': note['file_type'],
              'is_public': note['is_public'] ?? true,
              'updated_at': note['updated_at'],
              'tags': note['tags'],
              'author_name': note['profiles']?['username'] ?? 'Anonymous',
              'is_owned': false,
              'is_favorite': favoriteNoteIds.contains(note['id']),
              // folder_id on the saved_notes join row, not the underlying note
              'saved_folder_id': row['folder_id'],
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        _communityNotes = List<Map<String, dynamic>>.from(saved);
        _isLoadingSaved = false;
      });
      _loadRecentNotes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSaved = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading saved notes: $e')));
    }
  }

  Future<void> _unsaveNote(String noteId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('saved_notes')
          .delete()
          .eq('user_id', user.id)
          .eq('note_id', noteId);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Removed from saved notes')));
      await _loadSavedNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to unsave note: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // RECENT NOTES: folder-agnostic dashboard view (5 most recent)
  // ---------------------------------------------------------------------

  Future<void> _loadRecentNotes() async {
    setState(() => _isLoadingRecent = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingRecent = false);
      return;
    }

    try {
      // Ignores folder_id entirely - recent should reflect the whole collection.
      final ownedResponse = await _supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false)
          .limit(_recentNotesLimit);

      final favoritesResponse = await _supabase
          .from('favorites')
          .select('note_id')
          .eq('user_id', user.id);
      final favoriteNoteIds =
          (favoritesResponse as List)
              .map((fav) => fav['note_id'] as String)
              .toSet();

      final owned =
          (ownedResponse as List).map((note) {
            final noteMap = Map<String, dynamic>.from(note as Map);
            return {
              ...noteMap,
              'is_favorite': favoriteNoteIds.contains(noteMap['id']),
              'is_owned': true,
            };
          }).toList();

      // Merge with whatever community notes are already loaded, then take the
      // overall 5 most recent across both.
      final combined = [...owned, ..._communityNotes]..sort((a, b) {
        final aDate =
            DateTime.tryParse('${a['updated_at']}Z') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate =
            DateTime.tryParse('${b['updated_at']}Z') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (!mounted) return;
      setState(() {
        _recentNotes = combined.take(_recentNotesLimit).toList();
        _isLoadingRecent = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingRecent = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading recent notes: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // RECENT FOLDERS: dashboard preview (4 most recent)
  // ---------------------------------------------------------------------

  Future<void> _loadRecentFolders() async {
    setState(() => _isLoadingRecentFolders = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingRecentFolders = false);
      return;
    }

    try {
      final response = await _supabase
          .from('folders')
          .select()
          .eq('user_id', user.id)
          .order('updated_at', ascending: false)
          .limit(_recentFoldersLimit);

      if (!mounted) return;
      setState(() {
        _recentFolders = List<Map<String, dynamic>>.from(response as List);
        _isLoadingRecentFolders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingRecentFolders = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading folders: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // FOLDER OPTIONS (shared menu)
  // ---------------------------------------------------------------------

  void _showFolderOptionsMenu(Map<String, dynamic> folder) {
    showFolderOptionsMenu(
      context,
      folderId: folder['id'] as String,
      folderName: folder['name'] ?? 'Untitled folder',
      onRenamed: _loadRecentFolders,
      onDeleted: () {
        _loadRecentFolders();
        _loadRecentNotes();
      },
    );
  }

  // ---------------------------------------------------------------------
  // MOVE NOTES TO FOLDER
  // ---------------------------------------------------------------------

  Future<void> _showMoveToFolderSheet() async {
    if (_selectedNoteIds.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    String?
    pickerFolderId; // current folder shown inside picker (starts at root)
    List<Map<String, dynamic>> pickerFolders = [];
    final List<Map<String, dynamic>> pickerPath = [];
    bool pickerLoading = true;

    Future<void> loadPickerFolders(StateSetter setSheetState) async {
      setSheetState(() => pickerLoading = true);
      final query = _supabase.from('folders').select().eq('user_id', user.id);
      final response =
          pickerFolderId == null
              ? await query.filter('parent_id', 'is', null).order('name')
              : await query.eq('parent_id', pickerFolderId!).order('name');
      setSheetState(() {
        pickerFolders = List<Map<String, dynamic>>.from(response as List);
        pickerLoading = false;
      });
    }

    bool initialLoadTriggered = false;

    await showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            if (!initialLoadTriggered) {
              initialLoadTriggered = true;
              loadPickerFolders(setSheetState);
            }
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (pickerPath.isNotEmpty)
                          IconButton(
                            icon: const Icon(
                              Icons.arrow_back,
                              color: Colors.white,
                            ),
                            splashRadius: 20,
                            onPressed: () {
                              pickerPath.removeLast();
                              pickerFolderId =
                                  pickerPath.isEmpty
                                      ? null
                                      : pickerPath.last['id'];
                              loadPickerFolders(setSheetState);
                            },
                          ),
                        Expanded(
                          child: Text(
                            pickerPath.isEmpty
                                ? 'Move to Folder'
                                : pickerPath.last['name'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.grey),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child:
                          pickerLoading
                              ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 30),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: kPrimaryColor,
                                  ),
                                ),
                              )
                              : pickerFolders.isEmpty
                              ? const Padding(
                                padding: EdgeInsets.all(20),
                                child: Text(
                                  'No subfolders here',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              )
                              : ListView.builder(
                                shrinkWrap: true,
                                itemCount: pickerFolders.length,
                                itemBuilder: (context, index) {
                                  final folder = pickerFolders[index];
                                  return ListTile(
                                    leading: const Icon(
                                      Icons.folder,
                                      color: kAccentYellow,
                                    ),
                                    title: Text(
                                      folder['name'],
                                      style: const TextStyle(
                                        color: Colors.white,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.chevron_right,
                                      color: Colors.grey,
                                    ),
                                    onTap: () {
                                      pickerPath.add(folder);
                                      pickerFolderId = folder['id'];
                                      loadPickerFolders(setSheetState);
                                    },
                                  );
                                },
                              ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: () async {
                          Navigator.pop(context);
                          await _moveSelectedToFolder(pickerFolderId);
                        },
                        child: Text(
                          pickerPath.isEmpty
                              ? 'Move here (Root)'
                              : 'Move to "${pickerPath.last['name']}"',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Moves selected notes to [folderId]. Owned notes get their `notes.folder_id`
  /// updated. Community/saved notes aren't ours to update, so their folder
  /// placement lives on the `saved_notes.folder_id` join row instead.
  Future<void> _moveSelectedToFolder(String? folderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null || _selectedNoteIds.isEmpty) return;

    final allNotes = [..._recentNotes, ..._communityNotes];
    final ownedIds = <String>[];
    final savedIds = <String>[];

    for (final id in _selectedNoteIds) {
      final match = allNotes.firstWhere(
        (n) => n['id'] == id,
        orElse: () => <String, dynamic>{},
      );
      if (match['is_owned'] == true) {
        ownedIds.add(id);
      } else {
        savedIds.add(id);
      }
    }

    try {
      if (ownedIds.isNotEmpty) {
        await _supabase
            .from('notes')
            .update({'folder_id': folderId})
            .eq('user_id', user.id)
            .inFilter('id', ownedIds);
      }

      if (savedIds.isNotEmpty) {
        await _supabase
            .from('saved_notes')
            .update({'folder_id': folderId})
            .eq('user_id', user.id)
            .inFilter('note_id', savedIds);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedNoteIds.length} note(s) moved')),
      );

      _clearSelection();
      await Future.wait([_loadSavedNotes(), _loadRecentNotes()]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to move notes: $e')));
    }
  }

  // ---------------------------------------------------------------------
  // SELECTION TOOLBAR
  // ---------------------------------------------------------------------

  Widget _buildSelectionToolbar() {
    return IgnorePointer(
      ignoring: !_selectionMode,
      child: AnimatedSlide(
        offset: _selectionMode ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: _selectionMode ? 1 : 0,
          duration: const Duration(milliseconds: 160),
          child: Material(
            color: Colors.transparent,
            child: Container(
              // Background/shadow now lives OUTSIDE the SafeArea so it
              // extends underneath the status bar / notch instead of
              // leaving a transparent gap there.
              decoration: BoxDecoration(
                color: kCardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SafeArea(
                bottom: false,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  constraints: const BoxConstraints(
                    minHeight: kToolbarHeight,
                  ), // 56
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                        splashRadius: 20,
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _clearSelection();
                        },
                      ),
                      Text(
                        '${_selectedNoteIds.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'Selected',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const Spacer(),

                      /// Move to folder
                      IconButton(
                        icon: const Icon(Icons.folder_open_outlined),
                        color: Colors.white,
                        splashRadius: 20,
                        onPressed: () {
                          _showMoveToFolderSheet();
                        },
                      ),

                      /// Delete
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.white,
                        splashRadius: 20,
                        onPressed: () {
                          _confirmBatchDelete();
                        },
                      ),

                      /// Select all
                      IconButton(
                        icon: const Icon(Icons.select_all),
                        color: Colors.white,
                        splashRadius: 20,
                        onPressed: () {
                          setState(() {
                            _selectedNoteIds
                              ..clear()
                              ..addAll(
                                _filteredRecentNotes.map(
                                  (n) => n['id'] as String,
                                ),
                              );
                          });
                        },
                      ),

                      /// More (triple dot)
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        splashRadius: 20,
                        onPressed: () {
                          _showSelectionActionsBottomSheet();
                        },
                      ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSelectedNotes() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _selectedNoteIds.isEmpty) return;

    final allNotes = [..._recentNotes, ..._communityNotes];
    final ownedIds =
        _selectedNoteIds.where((id) {
          final match = allNotes.firstWhere(
            (n) => n['id'] == id,
            orElse: () => <String, dynamic>{},
          );
          return match['is_owned'] == true;
        }).toList();

    if (ownedIds.isEmpty) {
      _clearSelection();
      return;
    }

    try {
      await _supabase
          .from('notes')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'delete_expires_at':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 10))
                    .toIso8601String(),
          })
          .eq('user_id', user.id)
          .inFilter('id', ownedIds);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${ownedIds.length} notes moved to trash (10 days)'),
        ),
      );

      _clearSelection();
      _loadRecentNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete notes: $e')));
    }
  }

  void _confirmBatchDelete() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: kCardColor,
            title: const Text(
              'Delete notes',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Delete ${_selectedNoteIds.length} selected notes? This note will be deleted permanently after 10 days.',
              style: const TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteSelectedNotes();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _addSelectedToStarred() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _selectedNoteIds.isEmpty) return;

    try {
      final inserts =
          _selectedNoteIds.map((noteId) {
            return {'user_id': user.id, 'note_id': noteId};
          }).toList();

      await _supabase
          .from('favorites')
          .upsert(
            inserts,
            onConflict: 'user_id,note_id', // prevents duplicates
          );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedNoteIds.length} note(s) added to starred'),
        ),
      );

      _clearSelection();
      _loadRecentNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add to starred: $e')));
    }
  }

  bool _areAllSelectedStarred() {
    if (_selectedNoteIds.isEmpty) return false;

    final starredIds =
        _recentNotes
            .where((n) => n['is_favorite'] == true)
            .map((n) => n['id'] as String)
            .toSet();

    return _selectedNoteIds.every(starredIds.contains);
  }

  Future<void> _removeSelectedFromStarred() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _selectedNoteIds.isEmpty) return;

    try {
      await _supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .inFilter('note_id', _selectedNoteIds.toList());

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedNoteIds.length} removed from starred'),
        ),
      );

      _clearSelection();
      _loadRecentNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from starred: $e')),
      );
    }
  }

  void _showSelectionActionsBottomSheet() {
    final allStarred = _areAllSelectedStarred();
    showModalBottomSheet(
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
              const SizedBox(height: 12),

              // Selected count
              Text(
                '${_selectedNoteIds.length} Selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),
              const Divider(),

              // Add to starred
              _buildBottomSheetAction(
                icon: Icons.star_border,
                label: allStarred ? 'Remove from starred' : 'Add to starred',
                onTap: () {
                  Navigator.pop(context);
                  allStarred
                      ? _removeSelectedFromStarred()
                      : _addSelectedToStarred();
                },
              ),

              // Move to folder
              _buildBottomSheetAction(
                icon: Icons.folder_open_outlined,
                label: 'Move to folder',
                onTap: () {
                  Navigator.pop(context);
                  _showMoveToFolderSheet();
                },
              ),

              const Divider(),

              // 🗑 Delete
              _buildBottomSheetAction(
                icon: Icons.delete_outline,
                label: 'Delete',
                isDestructive: true,
                onTap: () {
                  Navigator.pop(context);
                  _confirmBatchDelete();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
    _loadSavedNotes();
    _loadRecentNotes();
    _loadRecentFolders();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setSelectionMode(bool value) {
    if (value) {
      FocusScope.of(context).unfocus();
    }
    setState(() {
      _selectionMode = value;
      if (!value) _selectedNoteIds.clear();
    });
    widget.onSelectionModeChanged?.call(value);
  }

  void _onLongPressNote(String noteId) {
    if (!_selectionMode) {
      _setSelectionMode(true);
    }
    setState(() {
      _selectedNoteIds.add(noteId);
    });
  }

  void _onTapNote(String noteId, VoidCallback openNote) {
    if (_selectionMode) {
      setState(() {
        if (_selectedNoteIds.contains(noteId)) {
          _selectedNoteIds.remove(noteId);
          if (_selectedNoteIds.isEmpty) {
            _setSelectionMode(false);
          }
        } else {
          _selectedNoteIds.add(noteId);
        }
      });
    } else {
      openNote();
    }
  }

  void _clearSelection() {
    _setSelectionMode(false);
  }

  Future<void> _deleteNote(String noteId, String fileUrl) async {
    try {
      final supabase = Supabase.instance.client;

      await supabase
          .from('notes')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'delete_expires_at':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 10))
                    .toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', supabase.auth.currentUser!.id);

      await _loadRecentNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note moved to trash (deleted in 10 days)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
      }
    }
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Unknown';

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

  // ---------------------------------------------------------------------
  // SEARCH FILTERING
  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> get _filteredRecentNotes {
    if (_searchQuery.isEmpty) return _recentNotes;
    return _recentNotes.where((note) {
      final title = (note['title'] ?? '').toString().toLowerCase();
      final author = (note['author_name'] ?? '').toString().toLowerCase();
      final tagsRaw = note['tags'];
      final tags = tagsRaw is List ? tagsRaw.join(' ').toLowerCase() : '';
      return title.contains(_searchQuery) ||
          author.contains(_searchQuery) ||
          tags.contains(_searchQuery);
    }).toList();
  }

  List<Map<String, dynamic>> get _filteredRecentFolders {
    if (_searchQuery.isEmpty) return _recentFolders;
    return _recentFolders
        .where(
          (folder) => (folder['name'] ?? '').toString().toLowerCase().contains(
            _searchQuery,
          ),
        )
        .toList();
  }

  // ---------------------------------------------------------------------
  // FOLDER GRID TILE: dashboard preview keeps the original 2-column grid
  // look for folders, separate from the notes list below it. Now includes
  // a kebab menu (Rename / Delete), matching FoldersPage's folder tiles.
  // ---------------------------------------------------------------------

  Widget _buildFolderGridTile(Map<String, dynamic> folder) {
    return GestureDetector(
      key: ValueKey('folder_${folder['id']}'),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FoldersPage(initialFolder: folder),
          ),
        ).then((_) {
          _loadRecentFolders();
          _loadRecentNotes();
        });
      },
      child: Container(
        padding: const EdgeInsets.only(left: 12, right: 4),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.folder, color: kAccentYellow, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                folder['name'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showFolderOptionsMenu(folder),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.more_vert, color: Colors.grey, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // NOTE TILE: shared renderer for owned vs community notes
  // ---------------------------------------------------------------------

  Widget _buildNoteTile(Map<String, dynamic> note) {
    final noteId = note['id'] as String;
    final isOwned = note['is_owned'] == true;
    final isSelected = _selectedNoteIds.contains(noteId);

    void moveThisNote() {
      setState(
        () =>
            _selectedNoteIds
              ..clear()
              ..add(noteId),
      );
      _showMoveToFolderSheet().then((_) => _selectedNoteIds.clear());
    }

    if (!isOwned) {
      // Community / saved note: selection + folder-move are supported, but
      // no edit and no hard delete (only "unsave").
      return GestureDetector(
        key: ValueKey('community_$noteId'),
        onLongPress: () => _onLongPressNote(noteId),
        onTap:
            () => _onTapNote(noteId, () {
              FileOpener.openFile(
                context,
                note['file_url'],
                '${note['title']}.${note['file_type']}',
              );
            }),
        child: NoteItem(
          noteId: noteId,
          selectionMode: _selectionMode,
          isOwned: false,
          authorName: note['author_name'],
          title: note['title'] ?? 'Untitled',
          description: note['description'],
          subtitle:
              'by ${note['author_name'] ?? 'Anonymous'} • ${_getTimeAgo(note['updated_at'])}',
          fileUrl: note['file_url'],
          fileType: note['file_type'],
          tags: note['tags'] != null ? List<String>.from(note['tags']) : [],
          isPublic: note['is_public'] ?? true,
          isFavorite: note['is_favorite'] ?? false,
          isSelected: isSelected,
          onDelete: () {},
          onUnsave: () => _unsaveNote(noteId),
          onMoveToFolder: moveThisNote,
          onRefresh: _loadSavedNotes,
        ),
      );
    }

    return GestureDetector(
      key: ValueKey('owned_$noteId'),
      onLongPress: () => _onLongPressNote(noteId),
      onTap:
          () => _onTapNote(noteId, () {
            FileOpener.openFile(
              context,
              note['file_url'],
              '${note['title']}.${note['file_type']}',
            );
          }),
      child: NoteItem(
        noteId: noteId,
        selectionMode: _selectionMode,
        isOwned: true,
        title: note['title'] ?? 'Untitled',
        description: note['description'],
        subtitle: 'Last edited ${_getTimeAgo(note['updated_at'])}',
        fileUrl: note['file_url'],
        fileType: note['file_type'],
        tags: note['tags'] != null ? List<String>.from(note['tags']) : [],
        isPublic: note['is_public'] ?? false,
        isFavorite: note['is_favorite'] ?? false,
        isSelected: isSelected,
        onDelete: () => _deleteNote(noteId, note['file_url']),
        onMoveToFolder: moveThisNote,
        onRefresh: _loadRecentNotes,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // FILES SECTION: unified dashboard preview (folders + notes together,
  // one "View All" into the single Drive-style FoldersPage).
  // ---------------------------------------------------------------------

  Widget _buildFilesSection() {
    final folders = _filteredRecentFolders;
    final notes = _filteredRecentNotes;
    final isLoading = _isLoadingRecent || _isLoadingRecentFolders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Recent',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FoldersPage()),
                ).then((_) {
                  _loadRecentFolders();
                  _loadRecentNotes();
                  _loadSavedNotes();
                });
              },
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View All',
                    style: TextStyle(
                      color: kPrimaryColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: kPrimaryColor, size: 18),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: _selectionMode ? 0 : 16),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            ),
          )
        else if (folders.isEmpty && notes.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    _searchQuery.isEmpty
                        ? Icons.note_add_outlined
                        : Icons.search_off,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _searchQuery.isEmpty
                        ? 'Nothing here yet'
                        : 'No matches for your search',
                    style: TextStyle(color: Colors.grey[400], fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (_searchQuery.isEmpty)
                    Text(
                      'Tap the + button to add your first note, or save one from the community',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          )
        else ...[
          if (folders.isNotEmpty)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2.8,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: folders.length,
              itemBuilder:
                  (context, index) => _buildFolderGridTile(folders[index]),
            ),
          if (folders.isNotEmpty && notes.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF3A3A3C), thickness: 1, height: 1),
            const SizedBox(height: 16),
          ],
          if (notes.isNotEmpty)
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: notes.length,
              itemBuilder: (context, index) => _buildNoteTile(notes[index]),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child:
                    (_isLoadingRecent && _isLoadingSaved)
                        ? const Center(
                          child: CircularProgressIndicator(
                            color: kPrimaryColor,
                          ),
                        )
                        : RefreshIndicator(
                          color: kPrimaryColor,
                          onRefresh: () async {
                            await Future.wait([
                              _loadSavedNotes(),
                              _loadRecentNotes(),
                              _loadRecentFolders(),
                            ]);
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: _selectionMode ? _clearSelection : null,
                            child: SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Search bar
                                    AnimatedPadding(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),
                                      curve: Curves.easeOut,
                                      padding: EdgeInsets.only(
                                        top: _selectionMode ? 16 : 0,
                                      ),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: kCardColor,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: TextField(
                                          controller: _searchController,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search by title, tags, or author...',
                                            hintStyle: const TextStyle(
                                              color: Colors.grey,
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: Colors.grey,
                                            ),
                                            suffixIcon:
                                                _searchQuery.isNotEmpty
                                                    ? IconButton(
                                                      icon: const Icon(
                                                        Icons.close,
                                                        color: Colors.grey,
                                                      ),
                                                      splashRadius: 18,
                                                      onPressed:
                                                          () =>
                                                              _searchController
                                                                  .clear(),
                                                    )
                                                    : null,
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 20,
                                                  vertical: 15,
                                                ),
                                          ),
                                          style: const TextStyle(
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),

                                    const SizedBox(height: 16),

                                    // Action Buttons
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _AnimatedActionButton(
                                            color: kPrimaryColor,
                                            icon: Icons.add,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const AddNotePage(),
                                                ),
                                              ).then((_) => _loadRecentNotes());
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _AnimatedActionButton(
                                            color: kAccentYellow,
                                            icon: Icons.star,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          FavoritesPage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _AnimatedActionButton(
                                            color: const Color(0xFF4B5563),
                                            icon: Icons.delete,
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder:
                                                      (context) =>
                                                          const TrashPage(),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 24),

                                    _buildFilesSection(),
                                    const SizedBox(height: 100),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
              ),
            ],
          ),
          _buildSelectionToolbar(),
        ],
      ),
    );
  }

  Widget _buildBottomSheetAction({
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
}

// Animated Action Button Widget
class _AnimatedActionButton extends StatefulWidget {
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _AnimatedActionButton({
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AnimatedActionButton> createState() => _AnimatedActionButtonState();
}

class _AnimatedActionButtonState extends State<_AnimatedActionButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: widget.color,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(widget.icon, color: Colors.white, size: 32),
            ),
          );
        },
      ),
    );
  }
}

class NoteItem extends StatefulWidget {
  final bool selectionMode;
  final bool isSelected;
  final String noteId;
  final String title;
  final String? description;
  final String subtitle;
  final String fileUrl;
  final String? fileType;
  final List<String> tags;
  final bool isPublic;
  final bool isFavorite;
  final bool isOwned;
  final String? authorName;
  final VoidCallback onDelete;
  final VoidCallback? onUnsave;
  final VoidCallback onMoveToFolder;
  final VoidCallback onRefresh;

  const NoteItem({
    required this.noteId,
    required this.title,
    this.description,
    required this.subtitle,
    required this.fileUrl,
    required this.fileType,
    required this.tags,
    required this.isPublic,
    required this.isFavorite,
    required this.isSelected,
    required this.onDelete,
    required this.selectionMode,
    required this.onMoveToFolder,
    required this.onRefresh,
    this.isOwned = true,
    this.authorName,
    this.onUnsave,
    super.key,
  });

  @override
  State<NoteItem> createState() => _NoteItemState();
}

class _NoteItemState extends State<NoteItem>
    with SingleTickerProviderStateMixin {
  late bool isFavorite;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _burstAnimation;

  @override
  void initState() {
    super.initState();
    isFavorite = widget.isFavorite;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.0,
          end: 0.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0.0,
          end: 1.3,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1.3,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_animationController);

    _burstAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
  }

  @override
  void didUpdateWidget(covariant NoteItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the star in sync if the underlying favorite state changes from
    // elsewhere (e.g. the shared "..." menu, or a batch star/unstar).
    if (oldWidget.isFavorite != widget.isFavorite) {
      isFavorite = widget.isFavorite;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final wasFavorite = isFavorite;
    try {
      await toggleNoteFavorite(
        context,
        noteId: widget.noteId,
        isFavorite: wasFavorite,
      );
      if (!wasFavorite) _animationController.forward(from: 0.0);
      if (mounted) setState(() => isFavorite = !wasFavorite);
    } catch (_) {
      // toggleNoteFavorite already surfaced a snackbar on failure.
    }
  }

  IconData _getFileIcon() {
    switch (widget.fileType?.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isSelected ? kPrimaryColor.withOpacity(0.18) : kCardColor,
        borderRadius: BorderRadius.circular(12),
        border:
            widget.isSelected
                ? Border.all(color: kPrimaryColor, width: 1.5)
                : null,
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child:
                widget.isSelected
                    ? Icon(Icons.check_circle, color: kPrimaryColor, size: 32)
                    : Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3C3C3E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getFileIcon(),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
          ),

          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!widget.isOwned)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kPrimaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Community',
                          style: TextStyle(
                            color: kPrimaryColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else if (widget.isPublic)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: kAccentYellow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Public',
                          style: TextStyle(
                            color: kAccentYellow,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 9,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Private',
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ],
            ),
          ),

          // Favorite star with animation
          if (!widget.selectionMode)
            GestureDetector(
              onTap: _toggleFavorite,
              child: SizedBox(
                width: 40,
                height: 40,
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Stack(
                      alignment: Alignment.center,
                      children: [
                        if (isFavorite && _burstAnimation.value > 0)
                          Transform.scale(
                            scale: _burstAnimation.value,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: kAccentYellow.withOpacity(
                                    1 - _burstAnimation.value,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        Transform.scale(
                          scale:
                              isFavorite && _animationController.isAnimating
                                  ? _scaleAnimation.value
                                  : 1.0,
                          child: Icon(
                            isFavorite ? Icons.star : Icons.star_border,
                            color: isFavorite ? kAccentYellow : Colors.grey,
                            size: 22,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          const SizedBox(width: 8),

          // Options menu - now the single shared note-options sheet from
          // note_folder_menus.dart, so this matches FoldersPage's grid
          // kebab exactly.
          if (!widget.selectionMode)
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(50),
                splashColor: Colors.white24,
                highlightColor: Colors.white10,
                onTap:
                    widget.isSelected
                        ? null
                        : () => showNoteOptionsMenu(
                          context,
                          noteId: widget.noteId,
                          title: widget.title,
                          description: widget.description,
                          fileUrl: widget.fileUrl,
                          fileType: widget.fileType,
                          tags: widget.tags,
                          isOwned: widget.isOwned,
                          isFavorite: isFavorite,
                          // List tiles already have a dedicated star button,
                          // so the shared menu skips its own star entry here.
                          showFavoriteAction: false,
                          onMoveToFolder: widget.onMoveToFolder,
                          onRefresh: widget.onRefresh,
                        ),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.more_vert, color: Colors.grey, size: 22),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
