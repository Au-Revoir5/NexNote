import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nexnote/backend/file_opener.dart';
import '../main/my_notes.dart'; // NoteItem widget + shared color constants (kPrimaryColor, etc.)

/// Shows every note the user has, flattened across all folders, plus
/// everything they've saved from the community. This is the "browse
/// everything" counterpart to the Recent dashboard on the main Notes page —
/// it deliberately ignores folder scoping.
class AllNotesPage extends StatefulWidget {
  const AllNotesPage({super.key});

  @override
  State<AllNotesPage> createState() => _AllNotesPageState();
}

class _AllNotesPageState extends State<AllNotesPage> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _ownedNotes = [];
  List<Map<String, dynamic>> _communityNotes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  bool _isLoading = true;
  bool _isLoadingSaved = true;

  final Set<String> _selectedNoteIds = {};
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    _loadOwnedNotes();
    _loadCommunityNotes();
    _searchController.addListener(_filterNotes);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------

  Future<void> _loadOwnedNotes() async {
    setState(() => _isLoading = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Deliberately unfiltered by folder_id - this page shows everything.
      final notesResponse = await _supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);

      final favoritesResponse = await _supabase
          .from('favorites')
          .select('note_id')
          .eq('user_id', user.id);
      final favoriteNoteIds = (favoritesResponse as List)
          .map((fav) => fav['note_id'] as String)
          .toSet();

      final owned = (notesResponse as List).map((note) {
        final noteMap = Map<String, dynamic>.from(note as Map);
        return {
          ...noteMap,
          'is_favorite': favoriteNoteIds.contains(noteMap['id']),
          'is_owned': true,
        };
      }).toList();

      if (!mounted) return;
      setState(() {
        _ownedNotes = owned;
        _isLoading = false;
      });
      _filterNotes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notes: $e')),
      );
    }
  }

  Future<void> _loadCommunityNotes() async {
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

      final favoritesResponse = await _supabase
          .from('favorites')
          .select('note_id')
          .eq('user_id', user.id);
      final favoriteNoteIds = (favoritesResponse as List)
          .map((fav) => fav['note_id'] as String)
          .toSet();

      final saved = (response as List)
          .where((row) => row['notes'] != null)
          .map((row) {
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
            };
          })
          .toList();

      if (!mounted) return;
      setState(() {
        _communityNotes = List<Map<String, dynamic>>.from(saved);
        _isLoadingSaved = false;
      });
      _filterNotes();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSaved = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading saved notes: $e')),
      );
    }
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();

    final combined = [..._ownedNotes, ..._communityNotes]
      ..sort((a, b) {
        final aDate = DateTime.tryParse('${a['updated_at']}Z') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = DateTime.tryParse('${b['updated_at']}Z') ??
            DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    setState(() {
      if (query.isEmpty) {
        _filteredNotes = combined;
      } else {
        _filteredNotes = combined.where((note) {
          final title = (note['title'] ?? '').toString().toLowerCase();
          final tags = note['tags'] as List<dynamic>?;
          final tagMatch =
              tags?.any((tag) => tag.toString().toLowerCase().contains(query)) ?? false;
          final authorMatch =
              (note['author_name'] ?? '').toString().toLowerCase().contains(query);
          return title.contains(query) || tagMatch || authorMatch;
        }).toList();
      }
    });
  }

  String _getTimeAgo(String? timestamp) {
    if (timestamp == null) return 'Unknown';

    final dateTime = DateTime.parse('${timestamp}Z').toLocal();
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
  // SELECTION
  // ---------------------------------------------------------------------

  void _setSelectionMode(bool value) {
    if (value) FocusScope.of(context).unfocus();
    setState(() {
      _selectionMode = value;
      if (!value) _selectedNoteIds.clear();
    });
  }

  void _onLongPressNote(String noteId) {
    if (!_selectionMode) _setSelectionMode(true);
    setState(() => _selectedNoteIds.add(noteId));
  }

  void _onTapNote(String noteId, VoidCallback openNote) {
    if (_selectionMode) {
      setState(() {
        if (_selectedNoteIds.contains(noteId)) {
          _selectedNoteIds.remove(noteId);
          if (_selectedNoteIds.isEmpty) _setSelectionMode(false);
        } else {
          _selectedNoteIds.add(noteId);
        }
      });
    } else {
      openNote();
    }
  }

  void _clearSelection() => _setSelectionMode(false);

  bool _areAllSelectedStarred() {
    if (_selectedNoteIds.isEmpty) return false;
    final starredIds = _ownedNotes
        .where((n) => n['is_favorite'] == true)
        .map((n) => n['id'] as String)
        .toSet();
    return _selectedNoteIds.every(starredIds.contains);
  }

  // ---------------------------------------------------------------------
  // MUTATIONS
  // ---------------------------------------------------------------------

  Future<void> _deleteNote(String noteId) async {
    try {
      await _supabase
          .from('notes')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'delete_expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(days: 10))
                .toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', _supabase.auth.currentUser!.id);

      await _loadOwnedNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Note moved to trash (deleted in 10 days)')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting note: $e')),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Removed from saved notes')),
      );
      await _loadCommunityNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to unsave note: $e')),
      );
    }
  }

  Future<void> _deleteSelectedNotes() async {
    final user = _supabase.auth.currentUser;
    if (user == null || _selectedNoteIds.isEmpty) return;

    try {
      await _supabase
          .from('notes')
          .update({
            'deleted_at': DateTime.now().toUtc().toIso8601String(),
            'delete_expires_at': DateTime.now()
                .toUtc()
                .add(const Duration(days: 10))
                .toIso8601String(),
          })
          .eq('user_id', user.id)
          .inFilter('id', _selectedNoteIds.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedNoteIds.length} notes moved to trash (10 days)')),
      );
      _clearSelection();
      _loadOwnedNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete notes: $e')),
      );
    }
  }

  void _confirmBatchDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text('Delete notes', style: TextStyle(color: Colors.white)),
        content: Text(
          'Delete ${_selectedNoteIds.length} selected notes? This note will be deleted permanently after 10 days.',
          style: const TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteSelectedNotes();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
          _selectedNoteIds.map((id) => {'user_id': user.id, 'note_id': id}).toList();
      await _supabase.from('favorites').upsert(inserts, onConflict: 'user_id,note_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedNoteIds.length} note(s) added to starred')),
      );
      _clearSelection();
      _loadOwnedNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to starred: $e')),
      );
    }
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
        SnackBar(content: Text('${_selectedNoteIds.length} removed from starred')),
      );
      _clearSelection();
      _loadOwnedNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove from starred: $e')),
      );
    }
  }

  Future<void> _moveSelectedToFolder(String? folderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null || _selectedNoteIds.isEmpty) return;

    try {
      await _supabase
          .from('notes')
          .update({'folder_id': folderId})
          .eq('user_id', user.id)
          .inFilter('id', _selectedNoteIds.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_selectedNoteIds.length} note(s) moved')),
      );
      _clearSelection();
      _loadOwnedNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to move notes: $e')),
      );
    }
  }

  Future<void> _showMoveToFolderSheet() async {
    if (_selectedNoteIds.isEmpty) return;
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    String? pickerFolderId; // current folder shown inside picker (starts at root)
    List<Map<String, dynamic>> pickerFolders = [];
    final List<Map<String, dynamic>> pickerPath = [];
    bool pickerLoading = true;
    bool initialLoadTriggered = false;

    Future<void> loadPickerFolders(StateSetter setSheetState) async {
      setSheetState(() => pickerLoading = true);
      final query = _supabase.from('folders').select().eq('user_id', user.id);
      final response = pickerFolderId == null
          ? await query.filter('parent_id', 'is', null).order('name')
          : await query.eq('parent_id', pickerFolderId!).order('name');
      setSheetState(() {
        pickerFolders = List<Map<String, dynamic>>.from(response as List);
        pickerLoading = false;
      });
    }

    await showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      isScrollControlled: true,
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
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            splashRadius: 20,
                            onPressed: () {
                              pickerPath.removeLast();
                              pickerFolderId =
                                  pickerPath.isEmpty ? null : pickerPath.last['id'];
                              loadPickerFolders(setSheetState);
                            },
                          ),
                        Expanded(
                          child: Text(
                            pickerPath.isEmpty ? 'Move to Folder' : pickerPath.last['name'],
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
                      child: pickerLoading
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 30),
                              child: Center(
                                child: CircularProgressIndicator(color: kPrimaryColor),
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
                                      leading: const Icon(Icons.folder, color: kAccentYellow),
                                      title: Text(
                                        folder['name'],
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      trailing:
                                          const Icon(Icons.chevron_right, color: Colors.grey),
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
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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

  // ---------------------------------------------------------------------
  // BOTTOM SHEETS / TOOLBAR
  // ---------------------------------------------------------------------

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

  void _showSelectionActionsBottomSheet() {
    final allStarred = _areAllSelectedStarred();
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
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
              Text(
                '${_selectedNoteIds.length} Selected',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              const Divider(),
              _buildBottomSheetAction(
                icon: Icons.star_border,
                label: allStarred ? 'Remove from starred' : 'Add to starred',
                onTap: () {
                  Navigator.pop(context);
                  allStarred ? _removeSelectedFromStarred() : _addSelectedToStarred();
                },
              ),
              _buildBottomSheetAction(
                icon: Icons.folder_open_outlined,
                label: 'Move to folder',
                onTap: () {
                  Navigator.pop(context);
                  _showMoveToFolderSheet();
                },
              ),
              const Divider(),
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
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(minHeight: kToolbarHeight),
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
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      splashRadius: 20,
                      onPressed: () {
                        HapticFeedback.mediumImpact();
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
                    IconButton(
                      icon: const Icon(Icons.folder_open_outlined),
                      color: Colors.white,
                      splashRadius: 20,
                      onPressed: _showMoveToFolderSheet,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline),
                      color: Colors.white,
                      splashRadius: 20,
                      onPressed: _confirmBatchDelete,
                    ),
                    IconButton(
                      icon: const Icon(Icons.select_all),
                      color: Colors.white,
                      splashRadius: 20,
                      onPressed: () {
                        setState(() {
                          _selectedNoteIds
                            ..clear()
                            ..addAll(_filteredNotes
                                .where((n) => n['is_owned'] == true)
                                .map((n) => n['id'] as String));
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      splashRadius: 20,
                      onPressed: _showSelectionActionsBottomSheet,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // NOTE TILE
  // ---------------------------------------------------------------------

  Widget _buildNoteTile(Map<String, dynamic> note) {
    final noteId = note['id'] as String;
    final isOwned = note['is_owned'] == true;

    if (!isOwned) {
      return GestureDetector(
        key: ValueKey('community_$noteId'),
        onTap: () {
          FileOpener.openFile(
            context,
            note['file_url'],
            '${note['title']}.${note['file_type']}',
          );
        },
        child: NoteItem(
          noteId: noteId,
          selectionMode: false,
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
          isSelected: false,
          onDelete: () {},
          onUnsave: () => _unsaveNote(noteId),
          onRefresh: _loadCommunityNotes,
        ),
      );
    }

    final isSelected = _selectedNoteIds.contains(noteId);
    return GestureDetector(
      key: ValueKey('owned_$noteId'),
      onLongPress: () => _onLongPressNote(noteId),
      onTap: () => _onTapNote(noteId, () {
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
        onDelete: () => _deleteNote(noteId),
        onRefresh: _loadOwnedNotes,
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kDarkSurface,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('All Notes', style: TextStyle(color: Colors.white)),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              AnimatedSlide(
                offset: _selectionMode ? const Offset(0, -1) : Offset.zero,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: _selectionMode ? 0 : 1,
                  duration: const Duration(milliseconds: 150),
                  child: IgnorePointer(
                    ignoring: _selectionMode,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A2A2E),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _searchController,
                          decoration: const InputDecoration(
                            hintText: 'Search by title, tags, or author...',
                            hintStyle: TextStyle(color: Colors.grey),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                          ),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: (_isLoading && _isLoadingSaved)
                    ? const Center(child: CircularProgressIndicator(color: kPrimaryColor))
                    : RefreshIndicator(
                        color: kPrimaryColor,
                        onRefresh: () async {
                          await Future.wait([_loadOwnedNotes(), _loadCommunityNotes()]);
                        },
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: _selectionMode ? _clearSelection : null,
                          child: _filteredNotes.isEmpty
                              ? ListView(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(60),
                                        child: Column(
                                          children: [
                                            Icon(Icons.note_add_outlined,
                                                size: 64, color: Colors.grey[600]),
                                            const SizedBox(height: 16),
                                            Text(
                                              _searchController.text.isEmpty
                                                  ? 'No notes yet'
                                                  : 'No notes found',
                                              style: TextStyle(
                                                color: Colors.grey[400],
                                                fontSize: 16,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              _searchController.text.isEmpty
                                                  ? 'Notes you add or save will show up here'
                                                  : 'Try a different search term',
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 14,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                                  itemCount: _filteredNotes.length,
                                  itemBuilder: (context, index) =>
                                      _buildNoteTile(_filteredNotes[index]),
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
}