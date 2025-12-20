import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

class FullscreenPdfPage extends StatelessWidget {
  final Uint8List pdfBytes;
  final String title;

  const FullscreenPdfPage({
    super.key,
    required this.pdfBytes,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final controller = PdfController(
      document: PdfDocument.openData(pdfBytes),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
      ),
      backgroundColor: Colors.black,
      body: PdfView(
        controller: controller,
        scrollDirection: Axis.vertical,
      ),
    );
  }
}
