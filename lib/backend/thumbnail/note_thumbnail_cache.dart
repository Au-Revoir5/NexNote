import 'dart:typed_data';

class NoteThumbnailCache {
  NoteThumbnailCache._();

  static final Map<String, Uint8List> _pdfThumbnails = {};
  static final Map<String, String> _docxPreviews = {};

  // ---------- PDF ----------
  static Uint8List? getPdf(String noteId) {
    return _pdfThumbnails[noteId];
  }

  static void setPdf(String noteId, Uint8List bytes) {
    _pdfThumbnails[noteId] = bytes;
  }

  // ---------- DOCX ----------
  static String? getDocx(String noteId) {
    return _docxPreviews[noteId];
  }

  static void setDocx(String noteId, String text) {
    _docxPreviews[noteId] = text;
  }

  // ---------- Cleanup ----------
  static void remove(String noteId) {
    _pdfThumbnails.remove(noteId);
    _docxPreviews.remove(noteId);
  }

  static void clear() {
    _pdfThumbnails.clear();
    _docxPreviews.clear();
  }
}
