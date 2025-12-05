import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class EnhanceNotePage extends StatefulWidget {
  const EnhanceNotePage({super.key});

  @override
  _EnhanceNotePageState createState() => _EnhanceNotePageState();
}

class _EnhanceNotePageState extends State<EnhanceNotePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myNotes = [];
  Map<String, dynamic>? _selectedNote;
  bool _isLoadingNotes = true;
  bool _isEnhancing = false;
  String? _aiOverview;
  
  final List<String> _enhancementOptions = [
    'Improve structure & clarity',
    'Add missing explanation',
    'Reformat into bullet points',
    'Fix grammar and language',
    'Highlight key points',
  ];
  
  List<String> _selectedOptions = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadMyNotes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMyNotes() async {
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) return;

      final response = await supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(20);

      setState(() {
        _myNotes = List<Map<String, dynamic>>.from(response);
        _isLoadingNotes = false;
      });
    } catch (e) {
      print('Error loading notes: $e');
      setState(() {
        _isLoadingNotes = false;
      });
    }
  }

  void _toggleOption(String option) {
    setState(() {
      if (_selectedOptions.contains(option)) {
        _selectedOptions.remove(option);
      } else {
        if (_selectedOptions.length < 3) {
          _selectedOptions.add(option);
        }
      }
    });
  }

  Future<void> _enhanceNote() async {
    if (_selectedNote == null || _selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a note and at least one enhancement option'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isEnhancing = true;
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

      final url =
          "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey";

      final prompt =
          "Here is a document:\n\n${_selectedNote!['extracted_text']}\n\n"
          "Please enhance it by applying: ${_selectedOptions.join(', ')}.";

      final response = await http.post(
        Uri.parse(url),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      final data = jsonDecode(response.body);

      // -----------------------------
      // FIXED GEMINI TEXT EXTRACTION
      // -----------------------------
      String extracted = "AI returned no text.";

      if (data["candidates"] != null && data["candidates"].isNotEmpty) {
        final candidate = data["candidates"][0];

        // Case 1: content.parts[].text
        if (candidate["content"]?["parts"] != null) {
          final parts = candidate["content"]["parts"];
          extracted = parts.map((p) => p["text"] ?? "").join("\n");
        }

        // Case 2: content is a LIST (older/alternate format)
        else if (candidate["content"] is List) {
          final parts = candidate["content"];
          extracted =
              parts.map((p) => p["text"] ?? "").join("\n");
        }
      }

      setState(() {
        _aiOverview = extracted.trim().isEmpty
            ? "AI returned no text."
            : extracted;
      });
    } catch (e) {
      print("Gemini error: $e");
      setState(() {
        _aiOverview = "Error contacting Gemini API.";
      });
    }

    setState(() {
      _isEnhancing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      body: Column(
        children: [
          // Tabs
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: kPrimaryColor,
                borderRadius: BorderRadius.circular(10),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              labelStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: const [
                Tab(text: 'Enhance'),
                Tab(text: 'Compare'),
                Tab(text: 'Combine'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildEnhanceTab(),
                _buildComingSoonTab('Compare'),
                _buildComingSoonTab('Combine'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Select from My Notes
          const Text(
            'Select one of My Notes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          if (_isLoadingNotes)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: kPrimaryColor),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _myNotes.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemBuilder: (context, index) {
                final note = _myNotes[index];
                final isSelected = _selectedNote?['id'] == note['id'];

                return NoteCardEnhance(
                  note: note,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      _selectedNote = note;
                      _aiOverview = null;
                    });
                  },
                );
              },
            ),

          const SizedBox(height: 24),

          // Enhancement options
          const Text(
            'What would you like to enhance?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          ..._enhancementOptions.map((option) {
            final isSelected = _selectedOptions.contains(option);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => _toggleOption(option),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? kPrimaryColor
                          : Colors.grey.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? kPrimaryColor
                              : Colors.transparent,
                          border: Border.all(
                            color: isSelected
                                ? kPrimaryColor
                                : Colors.grey,
                            width: 2,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        option,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),

          const SizedBox(height: 8),

          Text(
            'You can check 2-3 general options',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 24),

          // Enhance Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isEnhancing ? null : _enhanceNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: Colors.white.withOpacity(0.5),
              ),
              child: _isEnhancing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: kPrimaryColor,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Enhance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),

          // AI Overview section
          if (_aiOverview != null) ...[
            const SizedBox(height: 32),
            const Text(
              'AI Overview',
              style: TextStyle(
                color: kPrimaryColor,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Content Overview',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.fullscreen,
                          color: Colors.white,
                          size: 20,
                        ),
                        onPressed: () {},
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _aiOverview!,
                    style: TextStyle(
                      color: Colors.grey[300],
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.note_add, size: 18),
                label: const Text(
                  'Save as New Note',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'Want to compare or combine this\nnote with another?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _tabController.animateTo(1);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Compare',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      _tabController.animateTo(2);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimaryColor,
                      side: const BorderSide(color: Colors.white, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: const Text(
                      'Combine',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildComingSoonTab(String tabName) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.construction,
            color: Colors.grey[600],
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            '$tabName Feature',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Coming Soon',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// Note Card with Thumbnail
class NoteCardEnhance extends StatefulWidget {
  final Map<String, dynamic> note;
  final bool isSelected;
  final VoidCallback onTap;

  const NoteCardEnhance({
    super.key,
    required this.note,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<NoteCardEnhance> createState() => _NoteCardEnhanceState();
}

class _NoteCardEnhanceState extends State<NoteCardEnhance> {
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
    final fileType = widget.note['file_type']?.toLowerCase();
    if (fileType != 'pdf' && fileType != 'docx') {
      return;
    }

    setState(() {
      _isLoadingThumbnail = true;
      _thumbnailError = false;
    });

    try {
      if (fileType == 'pdf') {
        await _generatePdfThumbnail();
      } else if (fileType == 'docx') {
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

  Future<void> _generatePdfThumbnail() async {
    try {
      final fileUrl = widget.note['file_url'];
      Uint8List pdfBytes;
      
      if (fileUrl.contains('/storage/v1/object/')) {
        try {
          final uri = Uri.parse(fileUrl);
          final pathSegments = uri.pathSegments;
          
          final bucketIndex = pathSegments.indexOf('public') != -1 
              ? pathSegments.indexOf('public') + 1 
              : pathSegments.indexOf('sign') + 1;
          
          if (bucketIndex > 0 && bucketIndex < pathSegments.length) {
            final bucket = pathSegments[bucketIndex];
            final filePath = pathSegments.sublist(bucketIndex + 1).join('/');
            
            pdfBytes = await supabase.storage.from(bucket).download(filePath);
          } else {
            throw Exception('Could not parse bucket/path from URL');
          }
        } catch (e) {
          final response = await http.get(Uri.parse(fileUrl));
          if (response.statusCode != 200) {
            throw Exception('HTTP download failed: ${response.statusCode}');
          }
          pdfBytes = response.bodyBytes;
        }
      } else {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode != 200) {
          throw Exception('HTTP download failed: ${response.statusCode}');
        }
        pdfBytes = response.bodyBytes;
      }

      final document = await PdfDocument.openData(pdfBytes);
      final page = await document.getPage(1);
      final pageImage = await page.render(
        width: page.width * 2,
        height: page.height * 2,
      );
      
      final imageBytes = pageImage?.bytes;
      await page.close();

      if (mounted && imageBytes != null && imageBytes.isNotEmpty) {
        setState(() {
          _thumbnailBytes = imageBytes;
          _isLoadingThumbnail = false;
        });
      } else if (mounted) {
        setState(() {
          _thumbnailError = true;
          _isLoadingThumbnail = false;
        });
      }
    } catch (e) {
      debugPrint('PDF thumbnail error: $e');
      if (mounted) {
        setState(() {
          _thumbnailError = true;
          _isLoadingThumbnail = false;
        });
      }
    }
  }

  Future<void> _generateDocxThumbnail() async {
    try {
      final fileUrl = widget.note['file_url'];
      Uint8List docxBytes;
      
      if (fileUrl.contains('/storage/v1/object/')) {
        try {
          final uri = Uri.parse(fileUrl);
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
          final response = await http.get(Uri.parse(fileUrl));
          if (response.statusCode != 200) {
            throw Exception('HTTP download failed: ${response.statusCode}');
          }
          docxBytes = response.bodyBytes;
        }
      } else {
        final response = await http.get(Uri.parse(fileUrl));
        if (response.statusCode != 200) {
          throw Exception('HTTP download failed: ${response.statusCode}');
        }
        docxBytes = response.bodyBytes;
      }

      final extractedText = await _extractTextFromDocx(docxBytes);
      
      if (mounted) {
        setState(() {
          _docxPreviewText = extractedText;
          _isLoadingThumbnail = false;
        });
      }
    } catch (e) {
      debugPrint('DOCX thumbnail error: $e');
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
      final archive = ZipDecoder().decodeBytes(docxBytes);
      final documentXml = archive.firstWhere(
        (file) => file.name == 'word/document.xml',
      );
      
      final xmlContent = utf8.decode(documentXml.content as List<int>);
      final document = XmlDocument.parse(xmlContent);
      final textNodes = document.findAllElements('w:t');
      final textContent = textNodes.map((node) => node.innerText).join(' ');
      
      final cleanedText = textContent
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      
      return cleanedText.length > 500 
          ? '${cleanedText.substring(0, 500)}...' 
          : cleanedText;
    } catch (e) {
      debugPrint('Error extracting DOCX text: $e');
      return '';
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
          border: Border.all(
            color: widget.isSelected ? kPrimaryColor : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
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
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  widget.note['title'] ?? 'Untitled',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (widget.isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: kPrimaryColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
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

    if (_thumbnailBytes != null) {
      return Image.memory(
        _thumbnailBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

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
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.description,
                color: Colors.blue.shade700,
                size: 20,
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'DOCX',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                _docxPreviewText!,
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.grey.shade800,
                  height: 1.3,
                ),
                maxLines: 12,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    final fileType = widget.note['file_type']?.toLowerCase() ?? '';
    return Container(
      decoration: BoxDecoration(
        gradient: fileType == 'pdf'
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                fileType == 'pdf' 
                    ? Icons.picture_as_pdf
                    : Icons.description,
                size: 32,
                color: fileType == 'pdf'
                    ? Colors.red.shade400
                    : Colors.blue.shade400,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                fileType.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  color: fileType == 'pdf'
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