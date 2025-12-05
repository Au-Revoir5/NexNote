import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class AddNotePage extends StatefulWidget {
  const AddNotePage({super.key});

  @override
  _AddNotePageState createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _tagController = TextEditingController();
  
  File? _selectedFile;
  String? _fileName;
  String? _fileType;
  bool _isPublic = false;
  bool _isUploading = false;
  List<String> _tags = [];
  bool _fileError = false;
  bool _titleError = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTag(String tag) {
    final trimmedTag = tag.trim().toLowerCase();
    if (trimmedTag.isNotEmpty && !_tags.contains(trimmedTag)) {
      setState(() {
        _tags.add(trimmedTag);
        _tagController.clear();
      });
    }
  }

  void _removeTag(String tag) {
    setState(() {
      _tags.remove(tag);
    });
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx'],
      );

      if (result != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
          _fileName = result.files.single.name;
          _fileType = result.files.single.extension;
          _fileError = false;
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking file: $e');
    }
  }

  Future<void> _uploadNote() async {
    // Check title
    if (_titleController.text.trim().isEmpty) {
      setState(() {
        _titleError = true;
      });
    }
    
    // Check file
    if (_selectedFile == null) {
      setState(() {
        _fileError = true;
      });
    }
    
    // Stop if any errors
    if (_titleController.text.trim().isEmpty || _selectedFile == null) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;

      if (user == null) {
        _showErrorSnackBar('User not authenticated');
        return;
      }

      // Build correct file path WITH userId folder
      final ext = _fileType; // pdf / docx
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '${user.id}/$fileName';

      // Upload to: notes/<userId>/<fileName>
      await supabase.storage
          .from('notes')
          .upload(filePath, _selectedFile!);

      // Get public URL
      final fileUrl = supabase.storage.from('notes').getPublicUrl(filePath);

      // Insert note record into DB
      await supabase.from('notes').insert({
        'user_id': user.id,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        'file_url': fileUrl,
        'file_type': _fileType,
        'is_public': _isPublic,
        'tags': _tags,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Note uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      _showErrorSnackBar('Error uploading note: $e');
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }


  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kDarkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Note',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title Input
          const Text(
            'Title',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(10),
              border: _titleError
                  ? Border.all(color: Colors.red, width: 1.5)
                  : null,
            ),
            child: TextField(
              controller: _titleController,
              style: const TextStyle(color: Colors.white, fontSize: 15),
              decoration: const InputDecoration(
                hintText: 'Enter note title...',
                hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              ),
              onChanged: (value) {
                if (_titleError && value.trim().isNotEmpty) {
                  setState(() {
                    _titleError = false;
                  });
                }
              },
            ),
          ),

          if (_titleError) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                'Please enter a title',
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 12,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Description Input
          const Text(
            'Description (Optional)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: TextField(
              controller: _descriptionController,
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

          const SizedBox(height: 24),

          // Tags Section
          const Text(
            'Tags (Optional)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          
          // Tag input
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: kCardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: TextField(
                    controller: _tagController,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                    decoration: const InputDecoration(
                      hintText: 'Add a tag...',
                      hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    onSubmitted: _addTag,
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
                    if (_tagController.text.isNotEmpty) {
                      _addTag(_tagController.text);
                    }
                  },
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          
          // Display tags
          if (_tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kCardColor,
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
                        onTap: () => _removeTag(tag),
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

          const SizedBox(height: 24),

          // File Upload Section
          const Text(
            'Upload File',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _isUploading ? null : _pickFile,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _fileError
                      ? Colors.red
                      : _selectedFile != null
                          ? kPrimaryColor
                          : Colors.grey.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _selectedFile != null
                        ? Icons.check_circle
                        : Icons.upload_file,
                    color: _selectedFile != null
                        ? kPrimaryColor
                        : Colors.grey,
                    size: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _selectedFile != null
                        ? _fileName!
                        : 'Tap to upload PDF or DOCX',
                    style: TextStyle(
                      color: _selectedFile != null
                          ? Colors.white
                          : Colors.grey,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _fileType!.toUpperCase(),
                        style: const TextStyle(
                          color: kPrimaryColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          if (_fileError && _selectedFile == null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Text(
                'Please select a file',
                style: TextStyle(
                  color: Colors.red[400],
                  fontSize: 12,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Visibility Toggle
          const Text(
            'Visibility',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: kCardColor,
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPublic = false;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: !_isPublic
                            ? kPrimaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock,
                            color: !_isPublic
                                ? Colors.white
                                : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Private',
                            style: TextStyle(
                              color: !_isPublic
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _isPublic = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _isPublic
                            ? kPrimaryColor
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.public,
                            color: _isPublic
                                ? Colors.white
                                : Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Public',
                            style: TextStyle(
                              color: _isPublic
                                  ? Colors.white
                                  : Colors.grey,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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

          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              _isPublic
                  ? 'This note will be visible to everyone'
                  : 'Only you can see this note',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Upload Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isUploading ? null : _uploadNote,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                disabledBackgroundColor: kPrimaryColor.withOpacity(0.5),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Upload Note',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
          
          const SizedBox(height: 80), 
        ],
      ),
    ),
    );
  }
}