import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:nexnote/backend/file_opener.dart';
import 'package:nexnote/main/search.dart';
import 'package:nexnote/backend/fullscreen_pdf_page.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1A1A1A);
const kPagePadding = EdgeInsets.symmetric(horizontal: 20);

class NotePreviewPage extends StatelessWidget {
  final NoteItem note;
  final Uint8List? pdfThumbnail;
  final String? docxPreviewText;
  final Uint8List? pdfBytes;

  const NotePreviewPage({
    super.key,
    required this.note,
    this.pdfThumbnail,
    this.docxPreviewText,
    this.pdfBytes,
  });

  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays >= 365) return '${diff.inDays ~/ 365}y ago';
    if (diff.inDays >= 30) return '${diff.inDays ~/ 30}mo ago';
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'Just now';
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
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(note.title),
            _PreviewSection(
              pdfThumbnail,
              docxPreviewText, 
              note.fileType,
              onTap: pdfBytes == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenPdfPage(
                            pdfBytes: pdfBytes!,
                            title: note.title,
                          ),
                        ),
                      );
                    },
            ),
            if (note.description.isNotEmpty) ...[
              const _SectionLabel('Description'),
              _DescriptionSection(note.description),
            ],
            if (note.tags.isNotEmpty) ...[
              const _SectionLabel('Tags'),
              _TagSection(note.tags),
            ],
            const Divider(color: Color(0xFF2A2A2A), height: 32),
            _AuthorRow(note, _timeAgo),
            _ActionSection(note),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  final Uint8List? thumbnail;
  final String? docxPreviewText;
  final String fileType;
  final VoidCallback? onTap;

  const _PreviewSection(
    this.thumbnail,
    this.docxPreviewText,
    this.fileType, {
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: kPagePadding,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(12),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: thumbnail != null
                ? Image.memory(thumbnail!, fit: BoxFit.cover)
                : (fileType == 'docx' &&
                  docxPreviewText != null &&
                  docxPreviewText!.isNotEmpty)
                    ? _DocxTextPreview(docxPreviewText!)
                    : _Placeholder(fileType),
            ),
          ),
        ),
      ),
    );
  }
}

class _DescriptionSection extends StatelessWidget {
  final String? text;
  const _DescriptionSection(this.text);

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Text(
        text!,
        style: TextStyle(
          color: Colors.grey[300],
          fontSize: 14,
          height: 1.6,
        ),
        maxLines: 6,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
class _Title extends StatelessWidget {
  final String title;
  const _Title(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 26,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _TagSection extends StatelessWidget {
  final List<String> tags;
  const _TagSection(this.tags);

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: tags.map((tag) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey[700]!),
            ),
            child: Text(
              tag,
              style: TextStyle(
                color: Colors.grey[300],
                fontSize: 12,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final NoteItem note;
  final String Function(DateTime) timeAgo;

  const _AuthorRow(this.note, this.timeAgo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: kPrimaryColor,
            child: Text(
              note.author.isNotEmpty
                  ? note.author[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                note.author,
                style: const TextStyle(color: Colors.white),
              ),
              Text(
                'Updated ${timeAgo(note.updatedAt)}',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String fileType;
  const _Placeholder(this.fileType);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.insert_drive_file,
            size: 48,
            color: Colors.grey[700],
          ),
          const SizedBox(height: 8),
          Text(
            fileType.toUpperCase(),
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}


class _ActionSection extends StatelessWidget {
  final NoteItem note;

  const _ActionSection(this.note);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                FileOpener.openFile(
                  context,
                  note.fileUrl,
                  '${note.title}.${note.fileType}',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Open Note',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.download),
              label: const Text('Download'),
              onPressed: () {
                FileOpener.openFile(
                  context,
                  note.fileUrl,
                  '${note.title}.${note.fileType}',
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocxTextPreview extends StatelessWidget {
  final String text;
  const _DocxTextPreview(this.text);

  @override
  Widget build(BuildContext context) {
    final parts = text.split('\n\n');
    final title = parts.isNotEmpty ? parts.first : '';
    final body = parts.skip(1).join('\n\n');

    return ClipRect(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title (fixed height)
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            // Body (flexible, clipped)
            Expanded(
              child: Text(
                body,
                overflow: TextOverflow.fade,
                softWrap: true,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 6),

            // Footer hint (fixed)
            Text(
              'Preview truncated • Open to view full document',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          color: Colors.grey[500],
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}