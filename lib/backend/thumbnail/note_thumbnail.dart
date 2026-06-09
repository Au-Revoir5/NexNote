import 'dart:typed_data';
import 'package:flutter/material.dart';

class NoteThumbnail extends StatelessWidget {
  final String noteId;
  final String fileType;

  /// Optional pre-generated content
  final Uint8List? pdfThumbnail;
  final String? docxPreviewText;

  const NoteThumbnail({
    super.key,
    required this.noteId,
    required this.fileType,
    this.pdfThumbnail,
    this.docxPreviewText,
  });

  @override
  Widget build(BuildContext context) {
    // 1️⃣ PDF thumbnail available
    if (fileType.toLowerCase() == 'pdf' && pdfThumbnail != null) {
      return Image.memory(
        pdfThumbnail!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    // 2️⃣ DOCX preview available
    if (fileType.toLowerCase() == 'docx' &&
        docxPreviewText != null &&
        docxPreviewText!.isNotEmpty) {
      return _DocxMiniPreview(docxPreviewText!);
    }

    // 3️⃣ Fallback placeholder
    return _Fallback(fileType);
  }
}

/// ---------- DOCX PREVIEW ----------
class _DocxMiniPreview extends StatelessWidget {
  final String text;
  const _DocxMiniPreview(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFE3F2FD),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description, size: 16, color: Colors.blue),
              SizedBox(width: 6),
              Text(
                'DOCX',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Text(
              text,
              maxLines: 12,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 9,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------- FALLBACK ----------
class _Fallback extends StatelessWidget {
  final String fileType;
  const _Fallback(this.fileType);

  @override
  Widget build(BuildContext context) {
    final isPdf = fileType.toLowerCase() == 'pdf';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isPdf
              ? [Colors.red.shade50, Colors.red.shade100]
              : [Colors.blue.shade50, Colors.blue.shade100],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPdf ? Icons.picture_as_pdf : Icons.description,
              size: 42,
              color: isPdf ? Colors.red : Colors.blue,
            ),
            const SizedBox(height: 8),
            Text(
              fileType.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isPdf ? Colors.red.shade700 : Colors.blue.shade700,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
