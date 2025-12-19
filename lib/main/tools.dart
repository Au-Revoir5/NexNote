import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as im;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

/// Shared DOCX text extraction so both the card & the enhancer can use it
String extractTextFromDocxBytes(Uint8List docxBytes, {int? maxChars}) {
  try {
    final archive = ZipDecoder().decodeBytes(docxBytes);
    final documentXml = archive.firstWhere(
      (file) => file.name == 'word/document.xml',
    );

    final xmlContent = utf8.decode(documentXml.content as List<int>);
    final document = XmlDocument.parse(xmlContent);
    final textNodes = document.findAllElements('w:t');
    final textContent = textNodes.map((node) => node.innerText).join(' ');

    final cleanedText = textContent.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (maxChars != null && cleanedText.length > maxChars) {
      return '${cleanedText.substring(0, maxChars)}...';
    }

    return cleanedText;
  } catch (e) {
    debugPrint('Error extracting DOCX text: $e');
    return '';
  }
}

class EnhanceNotePage extends StatefulWidget {
  const EnhanceNotePage({super.key});

  @override
  _EnhanceNotePageState createState() => _EnhanceNotePageState();
}

class _EnhanceNotePageState extends State<EnhanceNotePage>
    with SingleTickerProviderStateMixin {
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

  /// Download file bytes from Supabase URL or plain HTTP
  Future<Uint8List> _downloadFileBytes(String fileUrl) async {
    final supabase = Supabase.instance.client;

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

          return await supabase.storage.from(bucket).download(filePath);
        } else {
          throw Exception('Could not parse bucket/path from URL');
        }
      } catch (e) {
        // Fallback to HTTP if storage download fails
        debugPrint('Supabase storage download failed, trying HTTP: $e');
      }
    }

    final response = await http.get(Uri.parse(fileUrl));
    if (response.statusCode != 200) {
      throw Exception('HTTP download failed: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  /// OCR: extract text from PDF bytes using ML Kit
  Future<String> _extractTextFromPdf(Uint8List pdfBytes) async {
    try {
      final document = await PdfDocument.openData(pdfBytes);
      final textRecognizer = TextRecognizer();
      final buffer = StringBuffer();

      for (int i = 1; i <= document.pagesCount; i++) {
        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: (page.width * 2),
          height: (page.height * 2),
        );
        await page.close();

        final imageBytes = pageImage?.bytes;
        if (imageBytes == null || imageBytes.isEmpty) continue;

        final rgbaBytes = imageBytes;
        final pageW = pageImage!.width ?? 0;
        final pageH = pageImage.height ?? 0;

        if (pageW == 0 || pageH == 0) {
          continue; // skip this page if render failed
        }

        // Convert RGBA → PNG
        final pngBytes = await _encodeToPng(rgbaBytes, pageW, pageH);

        // Save PNG to temp file
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/pdf_page_$i.png';
        final file = File(filePath);
        await file.writeAsBytes(pngBytes, flush: true);

        // OCR using ML Kit
        final inputImage = InputImage.fromFilePath(filePath);
        final recognizedText = await textRecognizer.processImage(inputImage);

        buffer.writeln(recognizedText.text);

      }

      await document.close();
      await textRecognizer.close();

      return buffer.toString().trim();
    } catch (e) {
      debugPrint('PDF OCR failed: $e');
      return '';
    }
  }

  Future<Uint8List> _encodeToPng(Uint8List rgba, int width, int height) async {
    final img = im.Image.fromBytes(
      width: width,
      height: height,
      bytes: rgba.buffer,   // ✔ correct type: ByteBuffer
      numChannels: 4,       // ✔ RGBA = 4 channels
    );

    return Uint8List.fromList(im.encodePng(img));
  }



  /// Decide how to get text: PDF → OCR, DOCX → XML, else → extracted_text column
  Future<String> _getTextForSelectedNote() async {
    final note = _selectedNote!;
    final fileType =
        (note['file_type'] ?? '').toString().toLowerCase().trim();

    // If note is based on a file (pdf/docx)
    if (fileType == 'pdf' || fileType == 'docx') {
      final fileUrl = (note['file_url'] ?? '').toString();
      if (fileUrl.isEmpty) {
        throw Exception('No file URL found in the selected note');
      }

      final fileBytes = await _downloadFileBytes(fileUrl);

      if (fileType == 'pdf') {
        final text = await _extractTextFromPdf(fileBytes);
        return text;
      } else {
        // DOCX
        final text = extractTextFromDocxBytes(fileBytes);
        return text;
      }
    }

    // Fallback to text stored in DB (for plain text notes)
    return (note['extracted_text'] ?? '').toString();
  }

  Future<void> _enhanceNote() async {
    if (_selectedNote == null || _selectedOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Please select a note and at least one enhancement option'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isEnhancing = true;
      _aiOverview = null;
    });

    try {
      final apiKey = dotenv.env['GEMINI_API_KEY'] ?? "";

      if (apiKey.isEmpty) {
        throw Exception('Gemini API key not found in .env file');
      }

      final url =
          "https://api.generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro-latest:generateContent?key=$apiKey";


      // 🔥 NEW: extract text dynamically (PDF OCR / DOCX / DB text)
      String extractedText = await _getTextForSelectedNote();

      if (extractedText.trim().isEmpty) {
        throw Exception('No text content found in the selected note');
      }

      final prompt =
          "You are a helpful assistant that enhances documents. "
          "Here is a document:\n\n$extractedText\n\n"
          "Please enhance it by applying the following improvements: ${_selectedOptions.join(', ')}. "
          "Return only the enhanced content without any preamble or explanation.";

      print('Sending request to Gemini API...');

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
          ],
          "generationConfig": {
            "temperature": 0.7,
            "topK": 40,
            "topP": 0.95,
            "maxOutputTokens": 2048,
          }
        }),
      );

      print('Response status: ${response.statusCode}');
      print('Response body: ${response.body}');

      if (response.statusCode != 200) {
        throw Exception(
            'API request failed with status ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);

      String extracted = "";

      // Check for error in response
      if (data["error"] != null) {
        throw Exception(
            'Gemini API Error: ${data["error"]["message"] ?? "Unknown error"}');
      }

      // Extract text from response
      if (data["candidates"] != null && data["candidates"].isNotEmpty) {
        final candidate = data["candidates"][0];

        // Check if content was blocked
        if (candidate["finishReason"] == "SAFETY") {
          throw Exception('Content was blocked by safety filters');
        }

        // Extract text from content.parts
        if (candidate["content"]?["parts"] != null) {
          final parts = candidate["content"]["parts"] as List;
          extracted = parts
              .where((p) => p["text"] != null)
              .map((p) => p["text"] as String)
              .join("\n");
        }
      }

      if (extracted.trim().isEmpty) {
        throw Exception('No text was generated by the AI');
      }

      setState(() {
        _aiOverview = extracted.trim();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note enhanced successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Gemini error: $e");

      String errorMessage = "Error enhancing note: ";
      if (e.toString().contains('API key')) {
        errorMessage += "Please check your API key in .env file";
      } else if (e.toString().contains('No text content')) {
        errorMessage += "Selected note has no text content";
      } else if (e.toString().contains('safety filters')) {
        errorMessage += "Content was blocked by safety filters";
      } else if (e.toString().contains('404')) {
        errorMessage += "API endpoint not found. Check model name";
      } else if (e.toString().contains('429')) {
        errorMessage += "Rate limit exceeded. Please try again later";
      } else {
        errorMessage += e.toString().replaceAll('Exception: ', '');
      }

      setState(() {
        _aiOverview = errorMessage;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isEnhancing = false;
        });
      }
    }
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
                          color:
                              isSelected ? kPrimaryColor : Colors.transparent,
                          border: Border.all(
                            color: isSelected ? kPrimaryColor : Colors.grey,
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
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: kPrimaryColor.withOpacity(0.5),
              ),
              child: _isEnhancing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Enhance',
                      style: TextStyle(
                        color: Colors.white,
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

      final extractedText =
          extractTextFromDocxBytes(docxBytes, maxChars: 500);

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
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
