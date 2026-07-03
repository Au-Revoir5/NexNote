import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../side/favorites.dart';
import '../side/trash.dart';
import 'package:nexnote/backend/file_opener.dart';
import 'add.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class NotesPage extends StatefulWidget {
  final ValueChanged<bool>? onSelectionModeChanged;
  const NotesPage({
    super.key,
    this.onSelectionModeChanged,
  });

  @override
  _NotesPageState createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage> {
  final TextEditingController _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  
  List<Map<String, dynamic>> _notes = [];
  List<Map<String, dynamic>> _filteredNotes = [];
  List<Map<String, dynamic>> _savedNotes = [];
  bool _isLoadingSaved = true;
  bool _isLoading = true;

  final Set<String> _selectedNoteIds = {};
  bool _selectionMode = false;

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
          notes (
            id,
            title,
            file_url,
            file_type,
            is_public,
            updated_at,
            publisher_id,
            profiles:publisher_id ( username, avatar_url )
          )
        ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final saved = (response as List)
        .where((row) => row['notes'] != null)
        .map((row) {
          final note = row['notes'];
          return {
            'id': note['id'],
            'title': note['title'] ?? 'Untitled',
            'file_url': note['file_url'],
            'file_type': note['file_type'],
            'updated_at': note['updated_at'],
            'author_name': note['profiles']?['username'] ?? 'Anonymous',
          };
        })
        .toList();

    if (!mounted) return;
    setState(() {
      _savedNotes = List<Map<String, dynamic>>.from(saved);
      _isLoadingSaved = false;
    });
  } catch (e) {
    if (!mounted) return;
    setState(() => _isLoadingSaved = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error loading saved notes: $e')),
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
    _loadSavedNotes();
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Failed to unsave note: $e')),
    );
  }
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
                constraints: const BoxConstraints(minHeight: kToolbarHeight), // 56
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
                      style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.2),
                    ),
                    const Spacer(),
                    /// Move to folder
                    IconButton(
                      icon: const Icon(Icons.folder_open_outlined),
                      color: Colors.white,
                      splashRadius: 20,
                      onPressed: () {
                        // TODO: move selected notes to folder
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
                            ..addAll(_filteredNotes.map((n) => n['id'] as String));
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
    );
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
        SnackBar(
          content: Text(
            '${_selectedNoteIds.length} notes moved to trash (10 days)',
          ),
        ),
      );

      _clearSelection();
      _loadNotes();
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
      final inserts = _selectedNoteIds.map((noteId) {
        return {
          'user_id': user.id,
          'note_id': noteId,
        };
      }).toList();

      await _supabase.from('favorites').upsert(
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
      _loadNotes();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add to starred: $e')),
      );
    }
  }

  bool _areAllSelectedStarred() {
    if (_selectedNoteIds.isEmpty) return false;

    final starredIds = _notes
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
        SnackBar(content: Text('${_selectedNoteIds.length} removed from starred')),
      );

      _clearSelection();
      _loadNotes();
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
                  // TODO: move selected notes
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
    _loadNotes();
    _loadSavedNotes();
    _searchController.addListener(_filterNotes);
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

  Future<void> _loadNotes() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Load notes
      final notesResponse = await _supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .filter('deleted_at', 'is', null)
          .order('updated_at', ascending: false);

      // Load user's favorites
      final favoritesResponse = await _supabase
          .from('favorites')
          .select('note_id')
          .eq('user_id', user.id);

      final favoriteNoteIds = (favoritesResponse as List)
          .map((fav) => fav['note_id'] as String)
          .toSet();

      // Add is_favorite flag to notes
      final notesWithFavorites = (notesResponse as List).map((note) {
        final noteMap = Map<String, dynamic>.from(note as Map);
        return {
          ...noteMap,
          'is_favorite': favoriteNoteIds.contains(noteMap['id']),
        };
      }).toList();

      setState(() {
        _notes = notesWithFavorites;
        _filteredNotes = _notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notes: $e')),
        );
      }
    }
  }

  void _filterNotes() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredNotes = _notes;
      } else {
        _filteredNotes = _notes.where((note) {
          final title = note['title'].toString().toLowerCase();
          final tags = note['tags'] as List<dynamic>?;
          final tagMatch = tags?.any((tag) => tag.toString().toLowerCase().contains(query)) ?? false;
          return title.contains(query) || tagMatch;
        }).toList();
      }
    });
  }

  Future<void> _deleteNote(String noteId, String fileUrl) async {
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

      await _loadNotes();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note moved to trash (deleted in 10 days)'),
          ),
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
    return Scaffold(
      backgroundColor: kDarkSurface,
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
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2E),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by title or tags...',
                        hintStyle: TextStyle(color: Colors.grey),
                        prefixIcon: Icon(Icons.search, color: Colors.grey),
                        border: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 20, vertical: _selectionMode ? 20 : 15),
                      ),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: kPrimaryColor),
                  )
                : RefreshIndicator(
                    color: kPrimaryColor,
                    onRefresh: () async {
                      await Future.wait([_loadNotes(), _loadSavedNotes()]);
                    },
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: _selectionMode ? _clearSelection : null,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Action Buttons
                            AnimatedPadding(
                              duration: const Duration(milliseconds: 180),
                              curve: Curves.easeOut,
                              padding: EdgeInsets.only(
                                top: _selectionMode ? 16 : 0, 
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _AnimatedActionButton(
                                      color: kPrimaryColor,
                                      icon: Icons.add,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => const AddNotePage()),
                                        ).then((_) => _loadNotes());
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _AnimatedActionButton(
                                      color: kAccentYellow,
                                      icon: Icons.star,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => FavoritesPage()),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _AnimatedActionButton(
                                      color: const Color(0xFF4B5563),
                                      icon: Icons.delete,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const TrashPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  )
                                ],
                              ),
                            ),


                            const SizedBox(height: 24),

                            // My Notes Header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'My Notes',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${_filteredNotes.length} note${_filteredNotes.length != 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),

                            SizedBox(height: _selectionMode ? 0 : 16),

                            // Notes List
                            if (_filteredNotes.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(40),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    color: _selectionMode
                                        ? Colors.black.withOpacity(0.08)
                                        : Colors.transparent,
                                    child: Column(
                                      children: [
                                      Icon(
                                        Icons.note_add_outlined,
                                        size: 64,
                                        color: Colors.grey[600],
                                      ),
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
                                            ? 'Tap the + button to add your first note'
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
                              )
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _filteredNotes.length,
                                itemBuilder: (context, index) {
                                  final note = _filteredNotes[index];
                                  final noteId = note['id'];
                                  final isSelected = _selectedNoteIds.contains(noteId);

                                  return GestureDetector(
                                    onLongPress: () => _onLongPressNote(noteId),
                                    onTap: () => _onTapNote(
                                      noteId,
                                      () {
                                        FileOpener.openFile(
                                          context,
                                          note['file_url'],
                                          '${note['title']}.${note['file_type']}',
                                        );
                                      },
                                    ),
                                    child: NoteItem(
                                      noteId: noteId,
                                      selectionMode: _selectionMode,
                                      title: note['title'] ?? 'Untitled',
                                      description: note['description'],
                                      subtitle: 'Last edited ${_getTimeAgo(note['updated_at'])}',
                                      fileUrl: note['file_url'],
                                      fileType: note['file_type'],
                                      tags: note['tags'] != null
                                          ? List<String>.from(note['tags'])
                                          : [],
                                      isPublic: note['is_public'] ?? false,
                                      isFavorite: note['is_favorite'] ?? false,
                                      isSelected: isSelected, 
                                      onDelete: () => _deleteNote(noteId, note['file_url']),
                                      onRefresh: _loadNotes,
                                    ),
                                  );
                                },
                              ),
                            if (_savedNotes.isNotEmpty || _isLoadingSaved) ...[
                              const SizedBox(height: 32),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Saved from Community',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${_savedNotes.length} note${_savedNotes.length != 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (_isLoadingSaved)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 20),
                                  child: Center(
                                    child: CircularProgressIndicator(color: kPrimaryColor),
                                  ),
                                )
                              else
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _savedNotes.length,
                                  itemBuilder: (context, index) {
                                    final note = _savedNotes[index];
                                    return _SavedNoteTile(
                                      note: note,
                                      timeAgo: _getTimeAgo(note['updated_at']),
                                      onTap: () {
                                        FileOpener.openFile(
                                          context,
                                          note['file_url'],
                                          '${note['title']}.${note['file_type']}',
                                        );
                                      },
                                      onUnsave: () => _unsaveNote(note['id']),
                                    );
                                  },
                                ),
                            ],
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
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
  final VoidCallback onDelete;
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
    required this.onRefresh,
    super.key,
  });

  @override
  State<NoteItem> createState() => _NoteItemState();
}

class _SavedNoteTile extends StatelessWidget {
  final Map<String, dynamic> note;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onUnsave;

  const _SavedNoteTile({
    required this.note,
    required this.timeAgo,
    required this.onTap,
    required this.onUnsave,
  });

  IconData _getFileIcon() {
    switch (note['file_type']?.toString().toLowerCase()) {
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
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
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
              child: Icon(_getFileIcon(), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note['title'] ?? 'Untitled',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'by ${note['author_name']} • $timeAgo',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_remove_outlined, color: Colors.grey),
              splashRadius: 20,
              onPressed: onUnsave,
              tooltip: 'Remove from saved',
            ),
          ],
        ),
      ),
    );
  }
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
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.3)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.3, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _shareNote() async {
    try {
      final supabase = Supabase.instance.client;

      final uri = Uri.parse(widget.fileUrl);
      final segments = uri.pathSegments;

      // /storage/v1/object/public/notes/<user_id>/<filename>
      final bucketIndex = segments.indexOf('notes');
      if (bucketIndex == -1) {
        throw Exception('Invalid file URL');
      }

      final storagePath = segments.sublist(bucketIndex + 1).join('/');

      // Create signed URL (1 hour)
      final signedUrl = await supabase.storage
          .from('notes')
          .createSignedUrl(storagePath, 60 * 60);

      await Share.share(
        '📄 ${widget.title}\n\n$signedUrl',
        subject: widget.title,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share note: $e')),
      );
    }
  }


  Future<void> _toggleFavorite() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    
    if (user == null) return;

    try {
      if (isFavorite) {
        await supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('note_id', widget.noteId);
      } else {
        await supabase.from('favorites').insert({
          'user_id': user.id,
          'note_id': widget.noteId,
        });
        _animationController.forward(from: 0.0);
      }

      setState(() {
        isFavorite = !isFavorite;
      });
    } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating favorite: $e')),
      );
    }
  }
  

  void _showEditDialog(BuildContext context) {
    final TextEditingController titleController = TextEditingController(text: widget.title);
    final TextEditingController descController = TextEditingController(text: widget.description ?? '');
    final TextEditingController tagController = TextEditingController();
    List<String> editableTags = List<String>.from(widget.tags);

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
                      .eq('id', widget.noteId);
                  
                  if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Note updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    widget.onRefresh();
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

  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildOption(context, Icons.edit, "Edit note", () {
              Navigator.pop(context);
              _showEditDialog(context);
            }),
            _buildOption(context, Icons.share, "Share", () {
              Navigator.pop(context);
              _shareNote();
            }),
            _buildOption(context, Icons.link, "Copy link", () async {
              Navigator.pop(context);

              try {
                final supabase = Supabase.instance.client;

                final uri = Uri.parse(widget.fileUrl);
                final segments = uri.pathSegments;

                final bucketIndex = segments.indexOf('notes');
                final storagePath = segments.sublist(bucketIndex + 1).join('/');

                final signedUrl = await supabase.storage
                    .from('notes')
                    .createSignedUrl(storagePath, 60 * 60); // 1 hour

                await Clipboard.setData(
                  ClipboardData(text: signedUrl),
                );

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Secure link copied (1 hour valid)')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to copy link: $e')),
                );
              }
            }),
            const Divider(color: Colors.grey),
            _buildOption(context, Icons.delete, "Remove", () {
              Navigator.pop(context);
              _showDeleteConfirmation(context);
            }, isDestructive: true),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kCardColor,
        title: const Text(
          'Delete Note',
          style: TextStyle(color: Colors.white),
        ),
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
              widget.onDelete();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, IconData icon, String label,
      VoidCallback onTap, {bool isDestructive = false}) {
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
        color: widget.isSelected
            ? kPrimaryColor.withOpacity(0.18)
            : kCardColor,
        borderRadius: BorderRadius.circular(12),
        border: widget.isSelected
            ? Border.all(color: kPrimaryColor, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          SizedBox(
          width: 40,
          height: 40,
          child: widget.isSelected
              ? Icon(
                  Icons.check_circle,
                  color: kPrimaryColor,
                  size: 32, 
                )
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
                    if (widget.isPublic)
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
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
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
                          scale: isFavorite && _animationController.isAnimating
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

          // Options menu
          if (!widget.selectionMode)
            Material(
              color: Colors.transparent,
              child: InkWell(
              borderRadius: BorderRadius.circular(50),
              splashColor: Colors.white24,
              highlightColor: Colors.white10,
              onTap: widget.isSelected ? null : () => _showOptionsMenu(context),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.more_vert,
                  color: Colors.grey,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}