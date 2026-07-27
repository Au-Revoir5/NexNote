import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:typed_data';
import 'package:nexnote/side/preview.dart';
import '../backend/thumbnail/note_thumbnail.dart';
import '../backend/thumbnail/note_thumbnail_cache.dart';
import '../backend/thumbnail/note_thumbnail_generator.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class SearchPage extends StatefulWidget {
  final ValueChanged<bool>? onSearchingChanged;
  final bool autoFocus;

  const SearchPage({
    super.key,
    this.onSearchingChanged,
    this.autoFocus = false,
  });

  static final GlobalKey<_SearchPageState> searchKey =
      GlobalKey<_SearchPageState>();

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final supabase = Supabase.instance.client;
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearching = false;

  String sortBy = "Last Edited (Recent)";
  List<NoteItem> notes = [];
  List<NoteItem> filteredNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();

    _fetchPublicNotes();

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) => focusSearch());
    }

    _searchFocusNode.addListener(() {
      final searching =
          _searchFocusNode.hasFocus || _searchController.text.isNotEmpty;

      widget.onSearchingChanged?.call(searching);

      setState(() {
        _isSearching = searching;
      });
    });
  }

  void focusSearch() {
    if (!_searchFocusNode.hasFocus) {
      _searchFocusNode.requestFocus();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicNotes() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await supabase
          .from('notes')
          .select('''
        id,
        title,
        description,
        file_url,
        file_type,
        tags,
        created_at,
        updated_at,
        is_public,
        publisher_id,
        profiles:publisher_id (
          username,
          avatar_url
          )
        ''')
          .eq('is_public', true)
    .order('updated_at', ascending: false);

      final currentUserId = supabase.auth.currentUser?.id;

      final fetchedNotes = (response as List).map((note) {
        final isPublic = note['is_public'] == true;
        final publisherId = note['publisher_id'] as String?;
        final username = isPublic
            ? (note['profiles']?['username'] ?? 'Anonymous')
            : 'Anonymous';

        final authorLabel = (publisherId != null && publisherId == currentUserId)
            ? 'Made by You'
            : 'Made by $username';

        return NoteItem(
          id: note['id'],
          title: note['title'] ?? 'Untitled',
          author: authorLabel,
          description: note['description'] ?? '', //
          fileUrl: note['file_url'],
          fileType: note['file_type'],
          tags: List<String>.from(note['tags'] ?? []),
          createdAt: DateTime.parse(note['created_at']),
          updatedAt: DateTime.parse(note['updated_at']),
          publisherId: note['publisher_id'] as String?,
        );
      }).toList();

      setState(() {
        notes = fetchedNotes;
        filteredNotes = fetchedNotes;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _filterNotes(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredNotes = List.from(notes);
      } else {
        filteredNotes = notes.where((note) {
          final titleMatch =
              note.title.toLowerCase().contains(query.toLowerCase());
          final tagMatch = note.tags
              .any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
          return titleMatch || tagMatch;
        }).toList();
      }
      _sortNotes();
    });
  }

  void _sortNotes() {
    setState(() {
      if (sortBy == "A–Z") {
        filteredNotes.sort((a, b) => a.title.compareTo(b.title));
      } else if (sortBy == "Z–A") {
        filteredNotes.sort((a, b) => b.title.compareTo(a.title));
      } else if (sortBy == "Last Edited (Old)") {
        filteredNotes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      } else {
        filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    });
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sortOption("Last Edited (Recent)"),
              _sortOption("Last Edited (Old)"),
              _sortOption("A–Z"),
              _sortOption("Z–A"),
            ],
          ),
        );
      },
    );
  }

  Widget _sortOption(String label) {
    final isSelected = sortBy == label;

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? kPrimaryColor : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check,
              color: kPrimaryColor,
            )
          : null,
      onTap: () {
        setState(() {
          sortBy = label;
          _sortNotes();
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPublicNotes,
                color: kPrimaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 90),
                        child: _isSearching
                            ? const SizedBox.shrink()
                            : Padding(
                                key: const ValueKey('search-header'),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                   
                                        const SizedBox(width: 10),
                                        const Text(
                                          'Find Notes You Need',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: -0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      '"Learning never exhausts the mind." — Leonardo da Vinci',
                                      style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 13,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 90),
                        height: _isSearching ? 12 : 32,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  focusNode: _searchFocusNode,
                                  onChanged: (value) {
                                    _filterNotes(value);
                                    widget.onSearchingChanged
                                        ?.call(value.isNotEmpty);
                                    setState(() {
                                      _isSearching = value.isNotEmpty ||
                                          _searchFocusNode.hasFocus;
                                    });
                                  },
                                  style: TextStyle(
                                    color: _searchController.text.isEmpty
                                        ? Colors.black.withValues(alpha: 0.5)
                                        : Colors.black,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Search',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    prefixIcon: AnimatedSwitcher(
                                      duration:
                                          const Duration(milliseconds: 90),
                                      child: _isSearching
                                          ? IconButton(
                                              key: const ValueKey('back'),
                                              icon: const Icon(
                                                  Icons.arrow_back,
                                                  color: Colors.grey),
                                              onPressed: () {
                                                _searchController.clear();
                                                _filterNotes('');
                                                _searchFocusNode.unfocus();
                                                setState(() {
                                                  _isSearching = false;
                                                });
                                              },
                                            )
                                          : const Icon(
                                              Icons.search,
                                              key: ValueKey('search'),
                                              color: Colors.grey,
                                            ),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: _showSortOptions,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: const Icon(Icons.tune,
                                    color: Colors.grey, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    color: kPrimaryColor,
                                  ),
                                ),
                              )
                            : filteredNotes.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(20),
                                            decoration: BoxDecoration(
                                              color: kCardColor,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              Icons.search_off,
                                              size: 40,
                                              color: Colors.grey[600],
                                            ),
                                          ),
                                          const SizedBox(height: 20),
                                          Text(
                                            _searchController.text.isEmpty
                                                ? 'No public notes available'
                                                : 'No notes found',
                                            style: TextStyle(
                                              color: Colors.grey[300],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            _searchController.text.isEmpty
                                                ? 'Check back later for shared notes'
                                                : 'Try a different search term',
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: filteredNotes.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.85,
                                    ),
                                    itemBuilder: (context, index) {
  final note = filteredNotes[index];
  return NoteCard(
    key: ValueKey(note.id),
    note: note,
    onTap: (pdfThumb, docxText, pdfBytes) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NotePreviewPage(
            note: note,
            pdfThumbnail: pdfThumb,
            docxPreviewText: docxText,
            pdfBytes: pdfBytes,
          ),
        ),
      );
    },
  );
},
                                  ),
                      ),
                      SizedBox(height: 40),
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
}

class NoteItem {
  final String id;
  final String title;
  final String author;
  final String description;
  final String fileUrl;
  final String fileType;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? publisherId;

  NoteItem({
    required this.id,
    required this.title,
    required this.author,
    required this.description,
    required this.fileUrl,
    required this.fileType,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
    required this.publisherId,
  });

  Color get color {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade100;
      case 'docx':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color get textColor => Colors.black;
}

class NoteCard extends StatefulWidget {
  final NoteItem note;
  final void Function(
    Uint8List? pdfThumbnail,
    String? docxPreviewText,
    Uint8List? pdfBytes,
  ) onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> {
  final supabase = Supabase.instance.client;
  Uint8List? _thumbnailBytes;
  Uint8List? _pdfBytes;
  String? _docxPreviewText;
  bool _isLoadingThumbnail = false;
  // ignore: unused_field
  bool _thumbnailError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    final type = widget.note.fileType.toLowerCase().trim();

    final cachedPdf = NoteThumbnailCache.getPdf(widget.note.id);
    final cachedDocx = NoteThumbnailCache.getDocx(widget.note.id);

    if (cachedPdf != null || cachedDocx != null) {
      setState(() {
        _thumbnailBytes = cachedPdf;
        _docxPreviewText = cachedDocx;
        _isLoadingThumbnail = false;
      });
      return;
    }

    setState(() {
      _isLoadingThumbnail = true;
    });

    try {
      if (type == 'pdf') {
        debugPrint('Generating PDF thumbnail for ${widget.note.id}');
        final bytes = await generatePdfThumbnail(widget.note.fileUrl);

        if (!mounted) return;

        NoteThumbnailCache.setPdf(widget.note.id, bytes);
        setState(() {
          _thumbnailBytes = bytes;
          _isLoadingThumbnail = false;
        });
      } else if (type == 'docx') {
        debugPrint('Generating DOCX preview for ${widget.note.id}');
        final text = await generateDocxPreview(widget.note.fileUrl);

        if (!mounted) return;

        NoteThumbnailCache.setDocx(widget.note.id, text);

        setState(() {
          _docxPreviewText = text;
          _isLoadingThumbnail = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() {});
        });
      } else {
        debugPrint('Unsupported file type: $type');
        setState(() {
          _isLoadingThumbnail = false;
        });
      }
    } catch (e, st) {
      debugPrint('Thumbnail error: $e');
      debugPrintStack(stackTrace: st);
      if (mounted) {
        setState(() {
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_isLoadingThumbnail) return;
        widget.onTap(_thumbnailBytes, _docxPreviewText, _pdfBytes);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _buildThumbnailWidget(),

              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.75),
                      ],
                      stops: const [0.0, 0.45, 1.0],
                    ),
                  ),
                ),
              ),

              Positioned(
                top: 10,
                left: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _fileTypeColor().withOpacity(0.9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_fileTypeIcon(), color: Colors.white, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        widget.note.fileType.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.note.tags.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: widget.note.tags.take(2).map((tag) {
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.25),
                                    width: 0.5,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      Text(
                        widget.note.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 11, color: Colors.white60),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              widget.note.author.replaceFirst('Made by ', ''),
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              if (_isLoadingThumbnail)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.3),
                    child: const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _fileTypeColor() {
    switch (widget.note.fileType.toLowerCase()) {
      case 'pdf':
        return const Color(0xFFE53935);
      case 'docx':
        return const Color(0xFF1E88E5);
      default:
        return kPrimaryColor;
    }
  }

  IconData _fileTypeIcon() {
    switch (widget.note.fileType.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildThumbnailWidget() {
    return NoteThumbnail(
      noteId: widget.note.id,
      fileType: widget.note.fileType,
      pdfThumbnail: _thumbnailBytes,
      docxPreviewText: _docxPreviewText,
    );
  }
}