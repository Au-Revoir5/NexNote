import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../helpers/file_opener.dart';
import '../helpers/thumbnail/note_thumbnail.dart';
import '../helpers/thumbnail/note_thumbnail_cache.dart';
import '../helpers/thumbnail/note_thumbnail_generator.dart';
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

class _FolderPageItem {
  final Map<String, dynamic> data;
  final bool isFolder;

  const _FolderPageItem.folder(this.data) : isFolder = true;
  const _FolderPageItem.note(this.data) : isFolder = false;
}

class _FolderNoteThumbnailWithCache extends StatefulWidget {
  final String noteId;
  final String fileUrl;
  final String fileType;

  const _FolderNoteThumbnailWithCache({
    required this.noteId,
    required this.fileUrl,
    required this.fileType,
  });

  @override
  State<_FolderNoteThumbnailWithCache> createState() =>
      _FolderNoteThumbnailWithCacheState();
}

class _FolderNoteThumbnailWithCacheState
    extends State<_FolderNoteThumbnailWithCache> {
  Uint8List? _pdf;
  String? _docx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final type = widget.fileType.toLowerCase().trim();

    _pdf = NoteThumbnailCache.getPdf(widget.noteId);
    _docx = NoteThumbnailCache.getDocx(widget.noteId);

    if (_pdf != null || _docx != null || widget.fileUrl.isEmpty) {
      if (mounted) setState(() {});
      return;
    }

    try {
      if (type == 'pdf') {
        final bytes = await generatePdfThumbnail(widget.fileUrl);
        if (!mounted) return;
        NoteThumbnailCache.setPdf(widget.noteId, bytes);
        _pdf = bytes;
      } else if (type == 'docx') {
        final text = await generateDocxPreview(widget.fileUrl);
        if (!mounted) return;
        NoteThumbnailCache.setDocx(widget.noteId, text);
        _docx = text;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Folder note thumbnail load error: $e');
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

class _FoldersPageState extends State<FoldersPage> {
  final _supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  // Calculate how many level deep is the folder
  late final int _initialFolderDepth = widget.initialFolder != null ? 1 : 0;

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
  final Set<String> _selectedFolderIds = {};
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

  void _showNoteOptionsMenu(Map<String, dynamic> note) {
    final noteId = note['id'] as String;
    final isOwned = note['is_owned'] == true;
    final isFavorite = _favoriteNoteIds.contains(noteId);

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
              _buildBottomSheetAction(
                icon: Icons.star_border,
                label: isFavorite ? 'Remove from starred' : 'Add to starred',
                onTap: () async {
                  Navigator.pop(context);
                  final user = _supabase.auth.currentUser;
                  if (user == null) return;
                  try {
                    if (isFavorite) {
                      await _supabase
                          .from('favorites')
                          .delete()
                          .eq('user_id', user.id)
                          .eq('note_id', noteId);
                    } else {
                      await _supabase.from('favorites').upsert({
                        'user_id': user.id,
                        'note_id': noteId,
                      }, onConflict: 'user_id,note_id');
                    }
                    await _loadFavorites();
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update starred: $e')),
                    );
                  }
                },
              ),
              _buildBottomSheetAction(
                icon: Icons.folder_open_outlined,
                label: 'Move to folder',
                onTap: () {
                  Navigator.pop(context);
                  // Reuse the existing move sheet by targeting just this
                  // note, without ever flipping on selection mode.
                  setState(
                    () =>
                        _selectedNoteIds
                          ..clear()
                          ..add(noteId),
                  );
                  _showMoveToFolderSheet().then(
                    (_) => _selectedNoteIds.clear(),
                  );
                },
              ),
              if (isOwned)
                _buildBottomSheetAction(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _deleteNote(noteId);
                  },
                )
              else
                _buildBottomSheetAction(
                  icon: Icons.remove_circle_outline,
                  label: 'Unsave',
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _unsaveNote(noteId);
                  },
                ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
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
              // Which folder this saved note has been filed into by the
              // current user. Lives on saved_notes (not notes) since it's
              // per-user, not a property of the underlying note itself.
              'folder_id': row['folder_id'],
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
      // Root: your unfiled notes + any saved community notes you haven't
      // filed into a folder yet.
      notes = [
        ..._ownedNotes.where((n) => n['folder_id'] == null),
        ..._communityNotes.where((n) => n['folder_id'] == null),
      ];
    } else {
      // Inside a folder: owned notes filed here + saved community notes
      // filed here.
      notes = [
        ..._ownedNotes.where((n) => n['folder_id'] == _currentFolderId),
        ..._communityNotes.where((n) => n['folder_id'] == _currentFolderId),
      ];
    }

    _sortItems(notes, isFolder: false);
    return notes;
  }

  List<_FolderPageItem> get _visibleItems {
    final items = [
      ..._visibleFolders.map(_FolderPageItem.folder),
      ..._visibleNotes.map(_FolderPageItem.note),
    ];
    _sortDisplayItems(items);
    return items;
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

  void _sortDisplayItems(List<_FolderPageItem> items) {
    int compareTitles(_FolderPageItem a, _FolderPageItem b) {
      return _itemTitle(
        a.data,
        isFolder: a.isFolder,
      ).compareTo(_itemTitle(b.data, isFolder: b.isFolder));
    }

    switch (_sortBy) {
      case 'Last Edited (Oldest)':
        items.sort((a, b) {
          final dateCompare = _itemDate(a.data).compareTo(_itemDate(b.data));
          if (dateCompare != 0) return dateCompare;
          return compareTitles(a, b);
        });
        break;
      case 'Alphabetical':
        items.sort(compareTitles);
        break;
      case 'Last Edited (Recent)':
      default:
        items.sort((a, b) {
          final dateCompare = _itemDate(b.data).compareTo(_itemDate(a.data));
          if (dateCompare != 0) return dateCompare;
          return compareTitles(a, b);
        });
        break;
    }
  }

  // ---------------------------------------------------------------------
  // SELECTION HELPERS
  // Community notes can now be selected (for starring / moving), but
  // deletion is owned-notes-only, so a few helpers split the current
  // selection by ownership.
  // ---------------------------------------------------------------------

  Set<String> get _selectedOwnedIds {
    final ownedIds = _ownedNotes.map((n) => n['id'] as String).toSet();
    return _selectedNoteIds.where(ownedIds.contains).toSet();
  }

  Set<String> get _selectedCommunityIds {
    final communityIds = _communityNotes.map((n) => n['id'] as String).toSet();
    return _selectedNoteIds.where(communityIds.contains).toSet();
  }

  int get _totalSelectedCount =>
      _selectedNoteIds.length + _selectedFolderIds.length;

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
    if (_folderPath.length > _initialFolderDepth) {
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
              'Delete "${folder['name']}"? Subfolders will also be deleted. Notes inside (owned or saved) will become unfiled, not deleted.',
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
      // Notes that were inside (owned or saved) may have had their
      // folder_id cleared server-side, so refresh both, not just the
      // folder tree.
      _loadFolders();
      _loadOwnedNotes();
      _loadCommunityNotes();
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
      if (!value) {
        _selectedNoteIds.clear();
        _selectedFolderIds.clear();
      }
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
          if (_totalSelectedCount == 0) _setSelectionMode(false);
        } else {
          _selectedNoteIds.add(noteId);
        }
      });
    } else {
      openNote();
    }
  }

  void _onLongPressFolder(String folderId) {
    if (!_selectionMode) _setSelectionMode(true);
    setState(() => _selectedFolderIds.add(folderId));
  }

  void _onTapFolder(Map<String, dynamic> folder) {
    final folderId = folder['id'] as String;
    if (_selectionMode) {
      setState(() {
        if (_selectedFolderIds.contains(folderId)) {
          _selectedFolderIds.remove(folderId);
          if (_totalSelectedCount == 0) _setSelectionMode(false);
        } else {
          _selectedFolderIds.add(folderId);
        }
      });
    } else {
      _openFolder(folder);
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

  // Delete is intentionally restricted to owned notes only. Community
  // (saved) notes aren't yours to delete - if any end up in the selection,
  // they're simply left alone and only the owned subset is trashed.
  Future<void> _deleteSelectedNotes() async {
    final user = _supabase.auth.currentUser;
    final ownedIds = _selectedOwnedIds;
    final folderIds = _selectedFolderIds.toList();

    if (user == null) return;

    try {
      if (ownedIds.isNotEmpty) {
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
            .inFilter('id', ownedIds.toList());
      }

      // Folders are deleted outright (not soft-deleted like notes);
      // contained notes are unfiled server-side, matching single-folder
      // delete behavior.
      for (final folderId in folderIds) {
        await _supabase
            .from('folders')
            .delete()
            .eq('id', folderId)
            .eq('user_id', user.id);
      }

      if (!mounted) return;
      final parts = <String>[];
      if (ownedIds.isNotEmpty) {
        parts.add(
          '${ownedIds.length} note${ownedIds.length > 1 ? 's' : ''} moved to trash (10 days)',
        );
      }
      if (folderIds.isNotEmpty) {
        parts.add(
          '${folderIds.length} folder${folderIds.length > 1 ? 's' : ''} deleted',
        );
      }
      if (parts.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(parts.join(', '))));
      }
      _clearSelection();
      _loadOwnedNotes();
      if (folderIds.isNotEmpty) {
        _loadFolders();
        _loadCommunityNotes();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
    }
  }

  void _confirmBatchDelete() {
    final ownedCount = _selectedOwnedIds.length;
    final folderCount = _selectedFolderIds.length;

    if (ownedCount == 0 && folderCount == 0) {
      // Selection is entirely saved community notes - nothing to delete.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Saved notes can't be deleted here - use unsave instead",
          ),
        ),
      );
      return;
    }

    final hasCommunityToo = _selectedCommunityIds.isNotEmpty;

    final messageParts = <String>[];
    if (ownedCount > 0) {
      messageParts.add(
        '$ownedCount note${ownedCount > 1 ? 's' : ''} (deleted permanently after 10 days)',
      );
    }
    if (folderCount > 0) {
      messageParts.add(
        '$folderCount folder${folderCount > 1 ? 's' : ''} (subfolders deleted too, contained notes unfiled)',
      );
    }

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: kCardColor,
            title: const Text(
              'Delete selected items',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Delete ${messageParts.join(' and ')}?'
              '${hasCommunityToo ? " Saved community notes in your selection won't be affected." : ""}',
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

  // Starring works the same for owned and community notes - favorites are
  // keyed by note_id regardless of who owns the underlying note. Folders
  // aren't starrable, so this only ever touches _selectedNoteIds.
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

  // Moving can include owned notes, community notes, and now folders in
  // one selection. Splits the ids and updates each table's parent/folder
  // reference separately: owned notes live in `notes.folder_id`, saved
  // community notes get a per-user folder_id on `saved_notes`, and folders
  // are reparented via `folders.parent_id`.
  Future<void> _moveSelectedToFolder(String? folderId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    if (_selectedNoteIds.isEmpty && _selectedFolderIds.isEmpty) return;

    final ownedIds = _selectedOwnedIds.toList();
    final communityIds = _selectedCommunityIds.toList();
    // Guard against moving a folder into itself.
    final folderIds = _selectedFolderIds.where((id) => id != folderId).toList();

    try {
      if (ownedIds.isNotEmpty) {
        await _supabase
            .from('notes')
            .update({'folder_id': folderId})
            .eq('user_id', user.id)
            .inFilter('id', ownedIds);
      }
      if (communityIds.isNotEmpty) {
        await _supabase
            .from('saved_notes')
            .update({'folder_id': folderId})
            .eq('user_id', user.id)
            .inFilter('note_id', communityIds);
      }
      if (folderIds.isNotEmpty) {
        await _supabase
            .from('folders')
            .update({'parent_id': folderId})
            .eq('user_id', user.id)
            .inFilter('id', folderIds);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${_totalSelectedCount} item(s) moved')),
      );
      _clearSelection();
      await Future.wait([
        _loadOwnedNotes(),
        _loadCommunityNotes(),
        _loadFolders(),
      ]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to move items: $e')));
    }
  }

  Future<void> _showMoveToFolderSheet() async {
    if (_selectedNoteIds.isEmpty && _selectedFolderIds.isEmpty) return;

    String?
    pickerFolderId; // current folder shown inside picker (starts at root)
    final List<Map<String, dynamic>> pickerPath = [];

    List<Map<String, dynamic>> childrenOf(String? parentId) {
      final children =
          _folders
              // Don't let a folder be navigated into itself while picking
              // a destination for a move that includes it.
              .where(
                (f) =>
                    f['parent_id'] == parentId &&
                    !_selectedFolderIds.contains(f['id']),
              )
              .toList();
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
    final hasOwnedSelected = _selectedOwnedIds.isNotEmpty;
    final hasFoldersSelected = _selectedFolderIds.isNotEmpty;
    final canDelete = hasOwnedSelected || hasFoldersSelected;
    final hasNoteSelection = _selectedNoteIds.isNotEmpty;
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
                '${_totalSelectedCount} Selected',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              const Divider(),
              // Starring only applies to notes, not folders.
              if (hasNoteSelection)
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
              // Delete only shown/enabled when the selection actually
              // includes at least one owned note or folder - saved
              // community notes can't be deleted from here.
              if (canDelete) ...[
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
              ],
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
      final hasOwnedSelected = _selectedOwnedIds.isNotEmpty;
      final hasFoldersSelected = _selectedFolderIds.isNotEmpty;
      final canDelete = hasOwnedSelected || hasFoldersSelected;
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
          '${_totalSelectedCount} Selected',
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
          // Delete icon is dimmed/disabled when nothing owned/foldered is
          // selected (e.g. only saved community notes are selected).
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: canDelete ? Colors.white : Colors.white24,
            splashRadius: 20,
            onPressed: canDelete ? _confirmBatchDelete : null,
          ),
          IconButton(
            icon: const Icon(Icons.select_all),
            color: Colors.white,
            splashRadius: 20,
            onPressed: () {
              setState(() {
                _selectedNoteIds
                  ..clear()
                  ..addAll(_visibleNotes.map((n) => n['id'] as String));
                _selectedFolderIds
                  ..clear()
                  ..addAll(_visibleFolders.map((f) => f['id'] as String));
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
                _folderPath.isEmpty ? 'My Notes' : _folderPath.last['name'],
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
          hintText: 'Search folders, notes, tags, or authors',
          hintStyle: const TextStyle(color: Colors.grey),
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

  Widget _buildBreadcrumb() {
    if (_folderPath.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < _folderPath.length; i++) ...[
            if (i != 0)
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
            _isGridView ? Icons.list : Icons.grid_view,
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
    final folderId = folder['id'] as String;
    final isSelected = _selectedFolderIds.contains(folderId);
    return GestureDetector(
      key: ValueKey('folder_${folder['id']}'),
      onTap: () => _onTapFolder(folder),
      onLongPress: () => _onLongPressFolder(folderId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.18) : kCardColor,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? Border.all(color: kPrimaryColor, width: 2)
                  : Border.all(color: Colors.transparent),
        ),
        child: Row(
          children: [
            if (isSelected)
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(
                  Icons.check_circle,
                  color: kPrimaryColor,
                  size: 32,
                ),
              )
            else
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
            if (!_selectionMode)
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
    final isSelected = _selectedNoteIds.contains(noteId);

    final openNote = () {
      FileOpener.openFile(
        context,
        note['file_url'],
        '${note['title']}.${note['file_type']}',
      );
    };

    if (!isOwned) {
      // Community (saved) notes now participate in selection too - so
      // they can be starred/moved alongside owned notes - just via the
      // same long-press/tap flow, not "onDelete" (that stays a no-op;
      // deletion of saved notes happens through unsave instead).
      return GestureDetector(
        key: ValueKey('community_$noteId'),
        onLongPress: () => _onLongPressNote(noteId),
        onTap: () => _onTapNote(noteId, openNote),
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
          isFavorite: isFavorite,
          isSelected: isSelected,
          onDelete: () {},
          onUnsave: () => _unsaveNote(noteId),
          onRefresh: _loadCommunityNotes,
        ),
      );
    }

    return GestureDetector(
      key: ValueKey('owned_$noteId'),
      onLongPress: () => _onLongPressNote(noteId),
      onTap: () => _onTapNote(noteId, openNote),
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

  Widget _buildFolderGridTile(Map<String, dynamic> folder) {
    final folderId = folder['id'] as String;
    final isSelected = _selectedFolderIds.contains(folderId);
    return GestureDetector(
      key: ValueKey('grid_folder_${folder['id']}'),
      onTap: () => _onTapFolder(folder),
      onLongPress: () => _onLongPressFolder(folderId),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.18) : kCardColor,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? Border.all(color: kPrimaryColor, width: 2)
                  : Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 6, 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isSelected)
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: kPrimaryColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    )
                  else if (_selectionMode)
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.radio_button_unchecked,
                        color: Colors.grey,
                        size: 18,
                      ),
                    )
                  else
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF3C3C3E),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(
                        Icons.folder,
                        color: kAccentYellow,
                        size: 16,
                      ),
                    ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      folder['name'] ?? 'Untitled folder',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (!_selectionMode)
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showFolderOptionsMenu(folder),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Big folder glyph filling the remaining space, like the
            // reference: pale/silver folder icon centered under the header.
            const Expanded(
              child: Center(
                child: Icon(Icons.folder, color: Color(0xFFC7C7CC), size: 132),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  IconData _noteGridIcon(Map<String, dynamic> note) {
    final type = (note['file_type'] ?? '').toString().toLowerCase();
    if (type == 'pdf') return Icons.picture_as_pdf;
    if (type == 'doc' || type == 'docx') return Icons.description;
    return Icons.insert_drive_file;
  }

  Color _noteGridIconColor(Map<String, dynamic> note) {
    final type = (note['file_type'] ?? '').toString().toLowerCase();
    if (type == 'pdf') return const Color(0xFFE53935);
    if (type == 'doc' || type == 'docx') return const Color(0xFF1E88E5);
    return kPrimaryColor;
  }

  Widget _buildNoteGridTile(Map<String, dynamic> note) {
    final noteId = note['id'] as String;
    final isOwned = note['is_owned'] == true;
    final isSelected = _selectedNoteIds.contains(noteId);
    final fileType = (note['file_type'] ?? '').toString();
    final openNote = () {
      FileOpener.openFile(
        context,
        note['file_url'],
        '${note['title']}.${note['file_type']}',
      );
    };

    return GestureDetector(
      key: ValueKey('grid_note_$noteId'),
      onLongPress: () => _onLongPressNote(noteId),
      onTap: () => _onTapNote(noteId, openNote),
      child: Container(
        decoration: BoxDecoration(
          color: kCardColor,
          borderRadius: BorderRadius.circular(12),
          border:
              isSelected
                  ? Border.all(color: kPrimaryColor, width: 2)
                  : Border.all(color: Colors.transparent),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: file-type icon, title (up to 2 lines), then either a
            // selection indicator (in selection mode) or a per-note kebab
            // menu that opens the same actions sheet used for batch
            // selection - it just pre-selects this one note first.
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 4, 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _noteGridIconColor(note).withOpacity(0.18),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(
                      _noteGridIcon(note),
                      color: _noteGridIconColor(note),
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      note['title'] ?? 'Untitled',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                  ),
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 2),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle
                            : Icons.radio_button_unchecked,
                        color: isSelected ? kPrimaryColor : Colors.grey,
                        size: 20,
                      ),
                    )
                  else
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () => _showNoteOptionsMenu(note),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.more_vert,
                          color: Colors.grey,
                          size: 18,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Big preview area, with a rounded corner and a small "shared"
            // people-badge overlaid bottom-right for community/saved notes -
            // owned notes get no badge, matching the reference screenshot.
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: Colors.white.withOpacity(0.04)),
                      _FolderNoteThumbnailWithCache(
                        noteId: noteId,
                        fileUrl: note['file_url'] ?? '',
                        fileType: fileType,
                      ),
                      if (!isOwned)
                        Positioned(
                          right: 6,
                          bottom: 6,
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.people_alt,
                              size: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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

    final items = _visibleItems;

    if (items.isEmpty) {
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
          childAspectRatio: 0.82,
        ),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          if (item.isFolder) {
            return _buildFolderGridTile(item.data);
          }
          return _buildNoteGridTile(item.data);
        },
      );
    }

    // Folders and notes are rendered from a single sorted collection so the
    // page behaves like one Drive-style file list.
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        if (item.isFolder) {
          return _buildFolderTile(item.data);
        }
        return _buildNoteTile(item.data);
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
          _folderPath.length <= _initialFolderDepth &&
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
                    _buildSortAndViewControls(),
                    const SizedBox(height: 12),
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
