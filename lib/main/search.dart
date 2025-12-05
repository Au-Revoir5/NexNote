import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final supabase = Supabase.instance.client;

  String sortBy = "Last Edited (Recent)";
  List<NoteItem> notes = [];
  List<NoteItem> filteredNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPublicNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchPublicNotes() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await supabase
          .from('notes')
          .select('*, profiles(username, avatar_url)')
          .eq('is_public', true)
          .order('updated_at', ascending: false);

      final fetchedNotes = (response as List).map((note) {
        final username = note['profiles']?['username'] ?? 'Anonymous';
        return NoteItem(
          id: note['id'],
          title: note['title'] ?? 'Untitled',
          author: 'Made by $username',
          fileUrl: note['file_url'],
          fileType: note['file_type'],
          tags: List<String>.from(note['tags'] ?? []),
          createdAt: DateTime.parse(note['created_at']),
          updatedAt: DateTime.parse(note['updated_at']),
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
          final titleMatch = note.title.toLowerCase().contains(query.toLowerCase());
          final tagMatch = note.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
          return titleMatch || tagMatch;
        }).toList();
      }
      _sortNotes();
    });
  }

  Future<void> _openFile(String fileUrl, String title) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find Notes You Need',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '"Learning never exhausts the mind."',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            Text(
                              '~ Leonardo da Vinci',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
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
                                  onChanged: _filterNotes,
                                  style: TextStyle(
                                    color: _searchController.text.isEmpty
                                        ? Colors.black.withValues(alpha: 0.5)
                                        : Colors.black,
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Search',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    prefixIcon:
                                        Icon(Icons.search, color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.tune, color: Colors.grey),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: IconButton(
                                onPressed: _showSortOptions,
                                icon: const Icon(Icons.sort, color: Colors.grey),
                                padding: const EdgeInsets.all(12),
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
                                          Icon(
                                            Icons.search_off,
                                            size: 64,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchController.text.isEmpty
                                                ? 'No public notes available'
                                                : 'No notes found',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredNotes.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.8,
                                    ),
                                    itemBuilder: (context, index) {
                                      return NoteCard(
                                        note: filteredNotes[index],
                                        onTap: () => _openFile(
                                          filteredNotes[index].fileUrl,
                                          filteredNotes[index].title,
                                        ),
                                      );
                                    },
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
}

class NoteItem {
  final String id;
  final String title;
  final String author;
  final String fileUrl;
  final String fileType;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.author,
    required this.fileUrl,
    required this.fileType,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
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
  final VoidCallback onTap;

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
  String? _docxPreviewText;
  bool _isLoadingThumbnail = false;
  bool _thumbnailError = false;

  @override
  void initState() {
    super.initState();
    _generateThumbnail();
  }

  Future<void> _generateThumbnail() async {
    if (widget.note.fileType.toLowerCase() != 'pdf' &&
        widget.note.fileType.toLowerCase() != 'docx') {
      return;
    }

    setState(() {
      _isLoadingThumbnail = true;
      _thumbnailError = false;
    });

    try {
      if (widget.note.fileType.toLowerCase() == 'pdf') {
        await _generatePdfThumbnail();
      } else if (widget.note.fileType.toLowerCase() == 'docx') {
        await _generateDocxThumbnail();
      }
    } catch (e) {
      debugPrint('Error generating thumbnail: $e');
      setState(() {
        _thumbnailError = true;
        _isLoadingThumbnail = false;
      });
    }
  }

  Future<void> _generateDocxThumbnail() async {
    try {
      debugPrint('Extracting DOCX content for: ${widget.note.fileUrl}');
      
      // Download DOCX file
      Uint8List docxBytes;
      
      if (widget.note.fileUrl.contains('/storage/v1/object/')) {
        try {
          final uri = Uri.parse(widget.note.fileUrl);
          final pathSegments = uri.pathSegments;
          
          final bucketIndex = pathSegments.indexOf('public') != -1 
              ? pathSegments.indexOf('public') + 1 
              : pathSegments.indexOf('sign') + 1;
          
          if (bucketIndex > 0 && bucketIndex < pathSegments.length) {
            final bucket = pathSegments[bucketIndex];
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            
            docxBytes = await supabase.storage.from(bucket).download(filePath);
          } else {
            throw Exception('Could not parse bucket/path from URL');
          }
        } catch (e) {
          debugPrint('Supabase download failed: $e, trying HTTP fallback');
          final response = await http.get(Uri.parse(widget.note.fileUrl));
          if (response.statusCode != 200) {
            throw Exception('HTTP download failed: ${response.statusCode}');
          }
          docxBytes = response.bodyBytes;
        }
      } else {
        final response = await http.get(Uri.parse(widget.note.fileUrl));
        if (response.statusCode != 200) {
          throw Exception('HTTP download failed: ${response.statusCode}');
        }
        docxBytes = response.bodyBytes;
      }

      // Extract text from DOCX
      final extractedText = await _extractTextFromDocx(docxBytes);
      
      if (mounted) {
        setState(() {
          _docxPreviewText = extractedText;
          _isLoadingThumbnail = false;
        });
        debugPrint('DOCX text extracted successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('DOCX thumbnail error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _thumbnailError = true;
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  Future<String> _extractTextFromDocx(Uint8List docxBytes) async {
    try {
      // DOCX is a ZIP archive, so we need to extract it
      final archive = ZipDecoder().decodeBytes(docxBytes);
      
      // Find document.xml which contains the text
      final documentXml = archive.firstWhere(
        (file) => file.name == 'word/document.xml',
      );
      
      // Read the XML content
      final xmlContent = utf8.decode(documentXml.content as List<int>);
      
      // Parse XML
      final document = XmlDocument.parse(xmlContent);
      
      // Extract text from all <w:t> elements (text nodes in Word XML)
      final textNodes = document.findAllElements('w:t');
      final textContent = textNodes.map((node) => node.innerText).join(' ');
      
      // Clean up and limit the text
      final cleanedText = textContent
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      // Return first 500 characters for preview
      return cleanedText.length > 500 
          ? '${cleanedText.substring(0, 500)}...' 
          : cleanedText;
    } catch (e) {
      debugPrint('Error extracting DOCX text: $e');
      return '';
    }
  }

  Future<void> _generatePdfThumbnail() async {
    try {
      debugPrint('Attempting to download PDF from: ${widget.note.fileUrl}');
      
      Uint8List pdfBytes;
      
      if (widget.note.fileUrl.contains('/storage/v1/object/')) {
        try {
          final uri = Uri.parse(widget.note.fileUrl);
          final pathSegments = uri.pathSegments;
          
          final bucketIndex = pathSegments.indexOf('public') != -1 
              ? pathSegments.indexOf('public') + 1 
              : pathSegments.indexOf('sign') + 1;
          
          if (bucketIndex > 0 && bucketIndex < pathSegments.length) {
            final bucket = pathSegments[bucketIndex];
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            
            debugPrint('Bucket: $bucket, Path: $filePath');
            
            pdfBytes = await supabase.storage.from(bucket).download(filePath);
            debugPrint('PDF downloaded via Supabase SDK, size: ${pdfBytes.length} bytes');
          } else {
            throw Exception('Could not parse bucket/path from URL');
          }
        } catch (e) {
          debugPrint('Supabase download failed: $e, trying HTTP fallback');
          final response = await http.get(Uri.parse(widget.note.fileUrl));
          if (response.statusCode != 200) {
            throw Exception('HTTP download failed: ${response.statusCode}');
          }
          pdfBytes = response.bodyBytes;
        }
      } else {
        final response = await http.get(Uri.parse(widget.note.fileUrl));
        if (response.statusCode != 200) {
          throw Exception('HTTP download failed: ${response.statusCode}');
        }
        pdfBytes = response.bodyBytes;
      }

      if (pdfBytes.isEmpty) {
        throw Exception('Downloaded PDF is empty');
      }

      debugPrint('PDF downloaded, size: ${pdfBytes.length} bytes');

      final document = await PdfDocument.openData(pdfBytes);
      debugPrint('PDF opened, pages: ${document.pagesCount}');
      
      if (document.pagesCount == 0) {
        throw Exception('PDF has no pages');
      }
      
      final page = await document.getPage(1);
      debugPrint('Page loaded');
      
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      
      debugPrint('Page rendered');
      
      final imageBytes = pageImage?.bytes;
      
      if (imageBytes == null) {
        await page.close();
        throw Exception('Failed to render page image');
      }
      
      debugPrint('Bytes extracted: ${imageBytes.length}');
      
      await page.close();

      if (mounted && imageBytes.isNotEmpty) {
        setState(() {
          _thumbnailBytes = imageBytes;
          _isLoadingThumbnail = false;
        });
        debugPrint('Thumbnail set successfully');
      } else if (mounted) {
        setState(() {
          _thumbnailError = true;
          _isLoadingThumbnail = false;
        });
        debugPrint('No image bytes available');
      }
    } catch (e, stackTrace) {
      debugPrint('PDF thumbnail error: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _thumbnailError = true;
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _buildThumbnailWidget(),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.note.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.note.author,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.note.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: widget.note.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.more_vert,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnailWidget() {
    if (_isLoadingThumbnail) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            color: kPrimaryColor,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_thumbnailError) {
      return _buildPlaceholder();
    }

    // Show PDF thumbnail
    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // Show DOCX text preview
    if (_docxPreviewText != null && _docxPreviewText!.isNotEmpty) {
      return _buildDocxPreview();
    }

    return _buildPlaceholder();
  }

  Widget _buildDocxPreview() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.white,
          ],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Word icon
          Row(
            children: [
              Icon(
                Icons.description,
                color: Colors.blue.shade700,
                size: 24,
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DOCX',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Text preview
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _docxPreviewText!,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade800,
                  height: 1.4,
                ),
                maxLines: 15,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: widget.note.fileType.toLowerCase() == 'pdf'
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade50,
                  Colors.red.shade100,
                ],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blue.shade50,
                  Colors.blue.shade100,
                ],
              ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                widget.note.fileType.toLowerCase() == 'pdf' 
                    ? Icons.picture_as_pdf
                    : Icons.description,
                size: 48,
                color: widget.note.fileType.toLowerCase() == 'pdf'
                    ? Colors.red.shade400
                    : Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                widget.note.fileType.toUpperCase(),
                style: TextStyle(
                  fontSize: 12,
                  color: widget.note.fileType.toLowerCase() == 'pdf'
                      ? Colors.red.shade700
                      : Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}