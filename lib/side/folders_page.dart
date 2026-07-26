import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:nexnote/backend/file_opener.dart';
import '../main/add.dart' show AddNotePage;
import '../main/my_notes.dart'; // NoteItem widget + shared color constants (kPrimaryColor, etc.)

/// Unified Drive-style browsing page: folders + your own notes + notes
/// you've saved from the community, all in one place.
///
/// - Normal mode: navigate folders like a file explorer (breadcrumbs,
///   create/rename/delete folders, move notes between folders).
/// - Search mode (as soon as you type in the search bar): ignores the
///   current folder and searches everything at once - folders by name,
///   your notes and saved community notes by title/tag/author - just like
///   Google Drive search does.
///
/// All folders and notes are loaded once up front and browsing is then
/// done client-side, so opening a folder is instant and doesn't hit the
/// network; only mutations (create/rename/delete/move/star) trigger a
/// refetch of the affected data.
class FoldersPage extends StatefulWidget {
  /// If provided, the page opens already inside this folder instead of at
  /// root (e.g. when jumping in from a "recent folder" card).
  final Map<String, dynamic>? initialFolder;

  const FoldersPage({super.key, this.initialFolder});

  @override
  State<FoldersPage> createState() => _FoldersPageState();
}

class _FoldersPageState extends State<FoldersPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Full, unfiltered data sets - loaded once, then filtered client-side for
  // both normal folder browsing and global search.
  List<Map<String, dynamic>> _folders = [];
  List<Map<String, dynamic>> _ownedNotes = [];
  List<Map<String, dynamic>> _communityNotes = [];
  Set<String> _favoriteNoteIds = {};

  bool _isLoadingFolders = true;
  bool _isLoadingOwnedNotes = true;
  bool _isLoadingCommunityNotes = true;

  String? _currentFolderId; // null = root
  final List<Map<String, dynamic>> _folderPath = []; // breadcrumb trail

  final Set<String> _selectedNoteIds = {};
  bool _selectionMode = false;
  bool _isSearchBarVisible = false;
  String _sortBy = 'Last Edited (Recent)';
  bool _isGridView = false;

  bool get _isLoading =>
      _isLoadingFolders || _isLoadingOwnedNotes || _isLoadingCommunityNotes;

  String get _searchQuery => _searchController.text.trim().toLowerCase();
  bool get _isSearching => _searchQuery.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.initialFolder != null) {
      _folderPath.add(widget.initialFolder!);
      _currentFolderId = widget.initialFolder!['id'];
    }
    _searchController.addListener(() => setState(() {}));
    _loadFolders();
    _loadFavorites();
    _loadOwnedNotes();
    _loadCommunityNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------
  // LOADING
  // ---------------------------------------------------------------------

  Future<void> _loadFolders() async {
    setState(() => _isLoadingFolders = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingFolders = false);
      return;
    }

    try {
      // All folders, not just the current level - needed so search can
      // match folders anywhere, and so breadcrumbs can be rebuilt when
      // jumping into a folder from a search result.
      final response = await _supabase
          .from('folders')
          .select()
          .eq('user_id', user.id)
          .order('name');

      if (!mounted) return;
      setState(() {
        _folders = List<Map<String, dynamic>>.from(response as List);
        _isLoadingFolders = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingFolders = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading folders: $e')));
    }
  }

  Future<void> _loadFavorites() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final response = await _supabase
          .from('favorites')
          .select('note_id')
          .eq('user_id', user.id);
      final ids =
          (response as List).map((fav) => fav['note_id'] as String).toSet();
      if (!mounted) return;
      setState(() => _favoriteNoteIds = ids);
    } catch (_) {
      // Non-critical - stars just won't reflect correctly until next load.
    }
  }

  Future<void> _loadOwnedNotes() async {
    setState(() => _isLoadingOwnedNotes = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingOwnedNotes = false);
      return;
    }

    try {
      // Deliberately unfiltered by folder_id - loaded once, filtered
      // client-side depending on where you're browsing / searching.
      final response = await _supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);

      final owned =
          (response as List).map((note) {
            return {
              ...Map<String, dynamic>.from(note as Map),
              'is_owned': true,
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        _ownedNotes = owned;
        _isLoadingOwnedNotes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingOwnedNotes = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading notes: $e')));
    }
  }

  Future<void> _loadCommunityNotes() async {
    setState(() => _isLoadingCommunityNotes = true);
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingCommunityNotes = false);
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
            };
          }).toList();

      if (!mounted) return;
      setState(() {
        _communityNotes = List<Map<String, dynamic>>.from(saved);
        _isLoadingCommunityNotes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingCommunityNotes = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading saved notes: $e')));
    }
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
  // DERIVED / FILTERED DATA
  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> get _visibleFolders {
    List<Map<String, dynamic>> folders;
    if (_isSearching) {
      final q = _searchQuery;
      folders =
          _folders
              .where(
                (f) => (f['name'] ?? '').toString().toLowerCase().contains(q),
              )
              .toList();
    } else {
      folders =
          _folders.where((f) => f['parent_id'] == _currentFolderId).toList();
    }

    _sortItems(folders, isFolder: true);
    return folders;
  }

  List<Map<String, dynamic>> get _visibleNotes {
    List<Map<String, dynamic>> notes;
    if (_isSearching) {
      final q = _searchQuery;
      notes =
          [..._ownedNotes, ..._communityNotes].where((note) {
            final title = (note['title'] ?? '').toString().toLowerCase();
            final tags = note['tags'] as List<dynamic>?;
            final tagMatch =
                tags?.any((t) => t.toString().toLowerCase().contains(q)) ??
                false;
            final authorMatch = (note['author_name'] ?? '')
                .toString()
                .toLowerCase()
                .contains(q);
            return title.contains(q) || tagMatch || authorMatch;
          }).toList();
    } else if (_currentFolderId == null) {
      // Root: your unfiled notes + everything you've saved from the
      // community, mixed together by recency. Community notes have no
      // folder of their own, so they only ever surface here at root.
      notes = [
        ..._ownedNotes.where((n) => n['folder_id'] == null),
        ..._communityNotes,
      ];
    } else {
      notes =
          _ownedNotes.where((n) => n['folder_id'] == _currentFolderId).toList();
    }

    _sortItems(notes, isFolder: false);
    return notes;
  }

  DateTime _itemDate(Map<String, dynamic> item) {
    final raw = item['updated_at'] ?? item['created_at'];
    if (raw == null) return DateTime.fromMillisecondsSinceEpoch(0);
    return DateTime.tryParse('${raw}Z') ??
        DateTime.tryParse(raw.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _itemTitle(Map<String, dynamic> item, {required bool isFolder}) {
    return (isFolder ? item['name'] : item['title'] ?? 'Untitled')
        .toString()
        .toLowerCase();
  }

  void _sortItems(List<Map<String, dynamic>> items, {required bool isFolder}) {
    switch (_sortBy) {
      case 'Last Edited (Oldest)':
        items.sort((a, b) {
          final dateCompare = _itemDate(a).compareTo(_itemDate(b));
          if (dateCompare != 0) return dateCompare;
          return _itemTitle(
            a,
            isFolder: isFolder,
          ).compareTo(_itemTitle(b, isFolder: isFolder));
        });
        break;
      case 'Alphabetical':
        items.sort(
          (a, b) => _itemTitle(
            a,
            isFolder: isFolder,
          ).compareTo(_itemTitle(b, isFolder: isFolder)),
        );
        break;
      case 'Last Edited (Recent)':
      default:
        items.sort((a, b) {
          final dateCompare = _itemDate(b).compareTo(_itemDate(a));
          if (dateCompare != 0) return dateCompare;
          return _itemTitle(
            a,
            isFolder: isFolder,
          ).compareTo(_itemTitle(b, isFolder: isFolder));
        });
        break;
    }
  }

  // ---------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------

  List<Map<String, dynamic>> _buildPathTo(String folderId) {
    final byId = {for (final f in _folders) f['id'] as String: f};
    final path = <Map<String, dynamic>>[];
    String? current = folderId;
    while (current != null) {
      final folder = byId[current];
      if (folder == null) break;
      path.insert(0, folder);
      current = folder['parent_id'] as String?;
    }
    return path;
  }

  void _openFolder(Map<String, dynamic> folder) {
    // Rebuilding the full path (rather than just appending) keeps
    // breadcrumbs correct whether you tapped a direct child while browsing
    // normally, or a folder surfaced from anywhere in a search result.
    final path = _buildPathTo(folder['id'] as String);
    setState(() {
      _folderPath
        ..clear()
        ..addAll(path);
      _currentFolderId = folder['id'] as String;
      if (_isSearching) {
        _searchController.clear();
        _isSearchBarVisible = false;
      }
    });
  }

  void _navigateToBreadcrumb(int index) {
    // index == -1 means root
    setState(() {
      if (index == -1) {
        _folderPath.clear();
        _currentFolderId = null;
      } else {
        final newPath = _folderPath.sublist(0, index + 1);
        _folderPath
          ..clear()
          ..addAll(newPath);
        _currentFolderId = _folderPath.last['id'];
      }
    });
  }

  bool _handleBackNavigation() {
    if (_isSearching) {
      _searchController.clear();
      setState(() => _isSearchBarVisible = false);
      return false;
    }
    if (_isSearchBarVisible) {
      setState(() => _isSearchBarVisible = false);
      return false;
    }
    if (_folderPath.isNotEmpty) {
      _navigateToBreadcrumb(_folderPath.length - 2);
      return false; // handled internally, don't pop the whole page
    }
    return true;
  }

  void _showSearchBar() {
    setState(() => _isSearchBarVisible = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _hideSearchBar() {
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() => _isSearchBarVisible = false);
  }

  Future<void> _openAddNotePage() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddNotePage()),
    );
    if (!mounted) return;
    await _loadOwnedNotes();
  }

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                ListTile(
                  leading: const Icon(
                    Icons.create_new_folder_outlined,
                    color: kAccentYellow,
                  ),
                  title: const Text(
                    'New folder',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showCreateFolderDialog();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.note_add_outlined,
                    color: kPrimaryColor,
                  ),
                  title: const Text(
                    'Add note',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _openAddNotePage();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // FOLDER CRUD
  // ---------------------------------------------------------------------

  void _showCreateFolderDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: kCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'New Folder',
              style: TextStyle(color: Colors.white),
            ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
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
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context);
                  await _createFolder(name);
                },
                child: const Text(
                  'Create',
                  style: TextStyle(color: kPrimaryColor),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _createFolder(String name) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from('folders').insert({
        'user_id': user.id,
        'parent_id': _currentFolderId,
        'name': name,
      });
      _loadFolders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create folder: $e')));
    }
  }

  void _showRenameFolderDialog(Map<String, dynamic> folder) {
    final controller = TextEditingController(text: folder['name']);
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: kCardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Rename Folder',
              style: TextStyle(color: Colors.white),
            ),
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
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
              ),
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
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) return;
                  Navigator.pop(context);
                  await _renameFolder(folder['id'], name);
                },
                child: const Text(
                  'Save',
                  style: TextStyle(color: kPrimaryColor),
                ),
              ),
            ],
          ),
    );
  }

  Future<void> _renameFolder(String folderId, String newName) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('folders')
          .update({
            'name': newName,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', folderId)
          .eq('user_id', user.id);
      _loadFolders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to rename folder: $e')));
    }
  }

  void _confirmDeleteFolder(Map<String, dynamic> folder) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: kCardColor,
            title: const Text(
              'Delete Folder',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Delete "${folder['name']}"? Subfolders will also be deleted. Notes inside will become unfiled, not deleted.',
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
                onPressed: () async {
                  Navigator.pop(context);
                  await _deleteFolder(folder['id']);
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

  Future<void> _deleteFolder(String folderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('folders')
          .delete()
          .eq('id', folderId)
          .eq('user_id', user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Folder deleted')));
      // Notes that were inside may have had their folder_id cleared
      // server-side, so refresh notes too, not just the folder tree.
      _loadFolders();
      _loadOwnedNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete folder: $e')));
    }
  }

  void _showFolderOptionsMenu(Map<String, dynamic> folder) {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildBottomSheetAction(
                  icon: Icons.drive_file_rename_outline,
                  label: 'Rename',
                  onTap: () {
                    Navigator.pop(context);
                    _showRenameFolderDialog(folder);
                  },
                ),
                const Divider(),
                _buildBottomSheetAction(
                  icon: Icons.delete_outline,
                  label: 'Delete folder',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _confirmDeleteFolder(folder);
                  },
                ),
              ],
            ),
          ),
    );
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
    return _selectedNoteIds.every(_favoriteNoteIds.contains);
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
            'delete_expires_at':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 10))
                    .toIso8601String(),
          })
          .eq('id', noteId)
          .eq('user_id', _supabase.auth.currentUser!.id);

      await _loadOwnedNotes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note moved to trash (deleted in 10 days)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting note: $e')));
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
      await _loadCommunityNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to unsave note: $e')));
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
            'delete_expires_at':
                DateTime.now()
                    .toUtc()
                    .add(const Duration(days: 10))
                    .toIso8601String(),
          })
          .eq('user_id', user.id)
          .inFilter('id', _selectedNoteIds.toList());

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_selectedNoteIds.length} notes moved to trash (10 days)',
          ),
        ),
      );
      _clearSelection();
      _loadOwnedNotes();
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
          _selectedNoteIds
              .map((id) => {'user_id': user.id, 'note_id': id})
              .toList();
      await _supabase
          .from('favorites')
          .upsert(inserts, onConflict: 'user_id,note_id');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_selectedNoteIds.length} note(s) added to starred'),
        ),
      );
      _clearSelection();
      _loadFavorites();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to add to starred: $e')));
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
        SnackBar(
          content: Text('${_selectedNoteIds.length} removed from starred'),
        ),
      );
      _clearSelection();
      _loadFavorites();
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to move notes: $e')));
    }
  }

  Future<void> _showMoveToFolderSheet() async {
    if (_selectedNoteIds.isEmpty) return;

    String?
    pickerFolderId; // current folder shown inside picker (starts at root)
    final List<Map<String, dynamic>> pickerPath = [];

    List<Map<String, dynamic>> childrenOf(String? parentId) {
      final children =
          _folders.where((f) => f['parent_id'] == parentId).toList();
      children.sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ),
      );
      return children;
    }

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
            // Built from the in-memory folder tree we already have, so this
            // is instant - no network round trip per level like before.
            final pickerFolders = childrenOf(pickerFolderId);
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
                              setSheetState(() {
                                pickerPath.removeLast();
                                pickerFolderId =
                                    pickerPath.isEmpty
                                        ? null
                                        : pickerPath.last['id'];
                              });
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
                          pickerFolders.isEmpty
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
                                      setSheetState(() {
                                        pickerPath.add(folder);
                                        pickerFolderId = folder['id'];
                                      });
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

  // ---------------------------------------------------------------------
  // BOTTOM SHEETS
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

  // ---------------------------------------------------------------------
  // APP BAR: normal folder-title bar, or a Drive-style selection bar that
  // takes over the app bar entirely (covers the title) while selecting.
  // ---------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    if (_selectionMode) {
      return AppBar(
        key: const ValueKey('selection_appbar'),
        backgroundColor: kCardColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          splashRadius: 20,
          onPressed: _clearSelection,
        ),
        title: Text(
          '${_selectedNoteIds.length} Selected',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
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
                  ..addAll(
                    _visibleNotes
                        .where((n) => n['is_owned'] == true)
                        .map((n) => n['id'] as String),
                  );
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
      );
    }

    return AppBar(
      key: const ValueKey('normal_appbar'),
      backgroundColor: kDarkSurface,
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      title:
          _isSearchBarVisible
              ? _buildSearchBar()
              : Text(
                _folderPath.isEmpty ? 'Folders' : _folderPath.last['name'],
                style: const TextStyle(color: Colors.white),
              ),
      actions: [
        IconButton(
          icon: Icon(
            _isSearchBarVisible ? Icons.close : Icons.search,
            color: Colors.white,
          ),
          splashRadius: 20,
          onPressed: _isSearchBarVisible ? _hideSearchBar : _showSearchBar,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _searchFocusNode,
        decoration: InputDecoration(
          hintText: 'Search folders, notes, tags, or authors...',
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon:
              _isSearching
                  ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.grey),
                    splashRadius: 18,
                    onPressed: () => _searchController.clear(),
                  )
                  : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 12,
          ),
        ),
        style: const TextStyle(color: Colors.white),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // BREADCRUMB
  // ---------------------------------------------------------------------

  Widget _buildBreadcrumb() {
    if (_folderPath.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => _navigateToBreadcrumb(-1),
            child: Row(
              children: const [
                Icon(Icons.home_outlined, size: 15, color: kPrimaryColor),
                SizedBox(width: 4),
                Text(
                  'Home',
                  style: TextStyle(color: kPrimaryColor, fontSize: 14),
                ),
              ],
            ),
          ),
          for (int i = 0; i < _folderPath.length; i++) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Icon(Icons.chevron_right, color: Colors.grey, size: 16),
            ),
            GestureDetector(
              onTap: () => _navigateToBreadcrumb(i),
              child: Text(
                _folderPath[i]['name'],
                style: TextStyle(
                  color:
                      i == _folderPath.length - 1
                          ? Colors.white
                          : kPrimaryColor,
                  fontSize: 14,
                  fontWeight:
                      i == _folderPath.length - 1
                          ? FontWeight.w600
                          : FontWeight.normal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // SORT / VIEW CONTROLS
  // ---------------------------------------------------------------------

  Widget _buildSortAndViewControls() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _showSortOptions,
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _sortBy,
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
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
            _isGridView ? Icons.grid_view : Icons.list,
            color: Colors.white70,
          ),
          splashRadius: 20,
          onPressed: () {
            setState(() => _isGridView = !_isGridView);
          },
        ),
      ],
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
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sortOption('Last Edited (Recent)'),
                _sortOption('Last Edited (Oldest)'),
                _sortOption('Alphabetical'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortOption(String option) {
    final isSelected = _sortBy == option;
    return ListTile(
      title: Text(
        option,
        style: TextStyle(
          color: isSelected ? kPrimaryColor : Colors.white,
          fontSize: 16,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: kPrimaryColor) : null,
      onTap: () {
        setState(() => _sortBy = option);
        Navigator.pop(context);
      },
    );
  }

  // ---------------------------------------------------------------------
  // UNIFIED FOLDER + NOTE LIST
  // Folders render with the same tile style as NoteItem (icon box, title,
  // trailing action) so there's no visual seam between folders and files -
  // it's one continuous list, like Drive. Same rendering applies whether
  // you're browsing a folder normally or looking at search results.
  // ---------------------------------------------------------------------

  Widget _buildFolderTile(Map<String, dynamic> folder) {
    return GestureDetector(
      key: ValueKey('folder_${folder['id']}'),
      onTap: () => _openFolder(folder),
      onLongPress: () => _showFolderOptionsMenu(folder),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3E),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.folder, color: kAccentYellow, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                folder['name'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.more_vert, color: Colors.grey, size: 22),
              splashRadius: 20,
              onPressed: () => _showFolderOptionsMenu(folder),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoteTile(Map<String, dynamic> note) {
    final noteId = note['id'] as String;
    final isOwned = note['is_owned'] == true;
    final isFavorite = _favoriteNoteIds.contains(noteId);

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
          isFavorite: isFavorite,
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
        isFavorite: isFavorite,
        isSelected: isSelected,
        onDelete: () => _deleteNote(noteId),
        onRefresh: _loadOwnedNotes,
      ),
    );
  }

  Widget _buildGridTile({
    required Key key,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    VoidCallback? onMenuTap,
    bool isSelected = false,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? Border.all(color: kPrimaryColor, width: 2)
                  : Border.all(color: Colors.transparent),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3C3C3E),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const Spacer(),
                if (isSelected)
                  const Icon(Icons.check_circle, color: kPrimaryColor, size: 22)
                else if (onMenuTap != null)
                  IconButton(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.grey,
                      size: 22,
                    ),
                    splashRadius: 20,
                    onPressed: onMenuTap,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderGridTile(Map<String, dynamic> folder) {
    return _buildGridTile(
      key: ValueKey('grid_folder_${folder['id']}'),
      icon: Icons.folder,
      iconColor: kAccentYellow,
      title: folder['name'] ?? 'Untitled folder',
      subtitle: 'Folder',
      onTap: () => _openFolder(folder),
      onLongPress: () => _showFolderOptionsMenu(folder),
      onMenuTap: () => _showFolderOptionsMenu(folder),
    );
  }

  IconData _noteGridIcon(Map<String, dynamic> note) {
    final type = (note['file_type'] ?? '').toString().toLowerCase();
    if (type == 'pdf') return Icons.picture_as_pdf_outlined;
    if (type == 'doc' || type == 'docx') return Icons.description_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Widget _buildNoteGridTile(Map<String, dynamic> note) {
    final noteId = note['id'] as String;
    final isOwned = note['is_owned'] == true;
    final isSelected = _selectedNoteIds.contains(noteId);

    return _buildGridTile(
      key: ValueKey('grid_note_$noteId'),
      icon: _noteGridIcon(note),
      iconColor: isOwned ? kPrimaryColor : Colors.white70,
      title: note['title'] ?? 'Untitled',
      subtitle:
          isOwned
              ? 'Last edited ${_getTimeAgo(note['updated_at'])}'
              : 'by ${note['author_name'] ?? 'Anonymous'}',
      isSelected: isSelected,
      onLongPress: isOwned ? () => _onLongPressNote(noteId) : null,
      onTap:
          isOwned
              ? () => _onTapNote(noteId, () {
                FileOpener.openFile(
                  context,
                  note['file_url'],
                  '${note['title']}.${note['file_type']}',
                );
              })
              : () {
                FileOpener.openFile(
                  context,
                  note['file_url'],
                  '${note['title']}.${note['file_type']}',
                );
              },
    );
  }

  Widget _buildEmptyState() {
    if (_isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
              const SizedBox(height: 16),
              Text(
                'No results for "${_searchController.text.trim()}"',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final isRoot = _folderPath.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.note_add_outlined, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              isRoot ? 'No notes yet' : 'This folder is empty',
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            if (isRoot) ...[
              const SizedBox(height: 8),
              Text(
                'Use the + button to add a folder or note',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildContentList() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(color: kPrimaryColor)),
      );
    }

    final folders = _visibleFolders;
    final notes = _visibleNotes;

    if (folders.isEmpty && notes.isEmpty) {
      return _buildEmptyState();
    }

    if (_isGridView) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 220,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.1,
        ),
        itemCount: folders.length + notes.length,
        itemBuilder: (context, index) {
          if (index < folders.length) {
            return _buildFolderGridTile(folders[index]);
          }
          return _buildNoteGridTile(notes[index - folders.length]);
        },
      );
    }

    // Folders and notes are rendered back-to-back in a single list with no
    // header text or gap between them - intentionally, so it reads as one
    // continuous collection rather than separate sections.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: folders.length + notes.length,
      itemBuilder: (context, index) {
        if (index < folders.length) {
          return _buildFolderTile(folders[index]);
        }
        return _buildNoteTile(notes[index - folders.length]);
      },
    );
  }

  // ---------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          _folderPath.isEmpty &&
          !_selectionMode &&
          !_isSearching &&
          !_isSearchBarVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_selectionMode) {
          _clearSelection();
          return;
        }
        _handleBackNavigation();
      },
      child: Scaffold(
        backgroundColor: kDarkSurface,
        appBar: _buildAppBar(),
        floatingActionButton:
            _selectionMode
                ? null
                : SizedBox(
                  width: 72,
                  height: 72,
                  child: FloatingActionButton(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.white,
                    elevation: 9,
                    onPressed: _showCreateMenu,
                    child: const Icon(Icons.add, size: 34),
                  ),
                ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        body: RefreshIndicator(
          color: kPrimaryColor,
          onRefresh: () async {
            await Future.wait([
              _loadFolders(),
              _loadFavorites(),
              _loadOwnedNotes(),
              _loadCommunityNotes(),
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
                    if (!_selectionMode &&
                        !_isSearching &&
                        _folderPath.isNotEmpty) ...[
                      _buildBreadcrumb(),
                      const SizedBox(height: 12),
                    ],
                    if (!_selectionMode) ...[
                      _buildSortAndViewControls(),
                      const SizedBox(height: 12),
                    ],
                    _buildContentList(),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
