import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

/// ---------- DOWNLOAD HELPER ----------
Future<Uint8List> _downloadFile(String fileUrl) async {
  // 1️⃣ Try Supabase Storage first
  if (fileUrl.contains('/storage/v1/object')) {
    try {
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;

      // works for both public & signed URLs
      final bucketIndex =
          segments.indexOf('public') != -1
              ? segments.indexOf('public') + 1
              : segments.indexOf('sign') + 1;

      if (bucketIndex > 0 && bucketIndex < segments.length) {
        final bucket = segments[bucketIndex];
        final path = segments.sublist(bucketIndex + 1).join('/');

        return await _supabase.storage.from(bucket).download(path);
      }
    } catch (_) {
      // fallback to HTTP
    }
  }

  // 2️⃣ HTTP fallback
  final res = await http.get(Uri.parse(fileUrl));
  if (res.statusCode != 200) {
    throw Exception('Failed to download file');
  }

  return res.bodyBytes;
}

/// ---------- PDF THUMBNAIL ----------
Future<Uint8List> generatePdfThumbnail(String fileUrl) async {
  final pdfBytes = await _downloadFile(fileUrl);

  final doc = await PdfDocument.openData(pdfBytes);
  final page = await doc.getPage(1);

  final image = await page.render(
    width: page.width.toDouble() * 2.0,
    height: page.height.toDouble() * 2.0,
    format: PdfPageImageFormat.png,
    backgroundColor: '#FFFFFF',
  );

  await page.close();
  await doc.close();

  if (image == null || image.bytes.isEmpty) {
    throw Exception('PDF render failed');
  }

  return image.bytes;
}

/// ---------- DOCX PREVIEW ----------
Future<String> generateDocxPreview(String fileUrl) async {
  final bytes = await _downloadFile(fileUrl);

  final archive = ZipDecoder().decodeBytes(bytes);

  final xmlFile = archive.firstWhere(
    (f) => f.name == 'word/document.xml',
    orElse: () => throw Exception('word/document.xml not found'),
  );

  final xml = XmlDocument.parse(
    String.fromCharCodes(xmlFile.content as List<int>),
  );

  final buffer = StringBuffer();

  // Iterate through paragraphs instead of raw text nodes
  for (final p in xml.findAllElements('w:p')) {
    final texts = p.findAllElements('w:t').map((t) => t.innerText).join();

    if (texts.trim().isEmpty) continue;

    // Detect heading style
    final style =
        p
            .findAllElements('w:pStyle')
            .map((e) => e.getAttribute('w:val'))
            .firstOrNull;

    if (style != null && style.toLowerCase().contains('heading')) {
      buffer.writeln(texts.trim().toUpperCase());
    } else {
      buffer.writeln(texts.trim());
    }

    buffer.writeln(); // paragraph spacing
  }

  final cleaned =
      buffer.toString().replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();

  // Limit size for thumbnails
  if (cleaned.length > 700) {
    return cleaned.substring(0, 700).trim() + '…';
  }

  return cleaned;
}
