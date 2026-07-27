import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:nexnote/backend/file_opener.dart';
import 'package:nexnote/main/search.dart';
import 'package:nexnote/backend/fullscreen_pdf_page.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1A1A1A);
const kPagePadding = EdgeInsets.symmetric(horizontal: 20);
const kAccentYellow = Color(0xFFFBBF24);

class NotePreviewPage extends StatefulWidget {
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

  @override
  State<NotePreviewPage> createState() => _NotePreviewPageState();
}

class _NotePreviewPageState extends State<NotePreviewPage> {
  final _supabase = Supabase.instance.client;

  bool _isFavorited = false;
  bool _isSaved = false;
  bool _loadingFav = true;
  bool _loadingSave = true;

  // Whether the current signed-in user is the one who published this
  // note to the community. Owners can't save/favorite their own note.
  bool get _isOwnNote {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;
    return widget.note.publisherId == user.id;
  }

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      setState(() {
        _loadingFav = false;
        _loadingSave = false;
      });
      return;
    }

    try {
      final favRes = await _supabase
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('note_id', widget.note.id)
          .maybeSingle();

      final saveRes = await _supabase
          .from('saved_notes')
          .select('id')
          .eq('user_id', user.id)
          .eq('note_id', widget.note.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _isFavorited = favRes != null;
        _isSaved = saveRes != null;
        _loadingFav = false;
        _loadingSave = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingFav = false;
        _loadingSave = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Please sign in to favorite notes');
      return;
    }

    if (_isOwnNote) {
      _showSnack("You can't favorite your own note");
      return;
    }

    final prevState = _isFavorited;
    setState(() => _isFavorited = !_isFavorited); // optimistic

    try {
      if (prevState) {
        await _supabase
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('note_id', widget.note.id);
      } else {
        await _supabase.from('favorites').insert({
          'user_id': user.id,
          'note_id': widget.note.id,
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFavorited = prevState); // revert on failure
      _showSnack('Failed to update favorite: $e');
    }
  }

  Future<void> _toggleSave() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      _showSnack('Please sign in to save notes');
      return;
    }

    if (_isOwnNote) {
      _showSnack("You can't save your own note");
      return;
    }

    final prevState = _isSaved;
    setState(() => _isSaved = !_isSaved); // optimistic

    try {
      if (prevState) {
        await _supabase
            .from('saved_notes')
            .delete()
            .eq('user_id', user.id)
            .eq('note_id', widget.note.id);
      } else {
        await _supabase.from('saved_notes').insert({
          'user_id': user.id,
          'note_id': widget.note.id,
        });
      }

      if (mounted) {
        _showSnack(prevState ? 'Removed from saved notes' : 'Saved to your library');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaved = prevState); // revert on failure
      _showSnack('Failed to update saved notes: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

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
    final isOwnNote = _isOwnNote;

    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kDarkSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Favorite/Save toggles — only shown when viewing someone
          // else's note. You can't favorite/save your own note, so
          // for your own notes these are omitted entirely rather
          // than shown disabled.
          if (!isOwnNote) ...[
            IconButton(
              tooltip: _isFavorited ? 'Remove favorite' : 'Favorite',
              onPressed: _loadingFav ? null : _toggleFavorite,
              icon: Icon(
                _isFavorited ? Icons.star : Icons.star_border,
                color: _isFavorited ? kAccentYellow : Colors.grey[400],
              ),
            ),
            IconButton(
              tooltip: _isSaved ? 'Remove from saved' : 'Save',
              onPressed: _loadingSave ? null : _toggleSave,
              icon: Icon(
                _isSaved ? Icons.bookmark : Icons.bookmark_border,
                color: _isSaved ? kPrimaryColor : Colors.grey[400],
              ),
            ),
          ],
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Title(widget.note.title),
            _PreviewSection(
              widget.pdfThumbnail,
              widget.docxPreviewText,
              widget.note.fileType,
              onTap: widget.pdfBytes == null
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FullscreenPdfPage(
                            pdfBytes: widget.pdfBytes!,
                            title: widget.note.title,
                          ),
                        ),
                      );
                    },
            ),
            if (widget.note.description.isNotEmpty) ...[
              const _SectionLabel('Description'),
              _DescriptionSection(widget.note.description),
            ],
            if (widget.note.tags.isNotEmpty) ...[
              const _SectionLabel('Tags'),
              _TagSection(widget.note.tags),
            ],
            const Divider(color: Color(0xFF2A2A2A), height: 32),
            _AuthorRow(widget.note, _timeAgo),
            _ActionRow(widget.note),
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
    // No thumbnail at all (docx/placeholder cases) — just use the
    // classic 16:9 card, no decode needed.
    if (thumbnail == null) {
      return _buildCard(
        context,
        aspectRatio: 16 / 9,
        child: (fileType == 'docx' &&
                docxPreviewText != null &&
                docxPreviewText!.isNotEmpty)
            ? _DocxTextPreview(docxPreviewText!)
            : _Placeholder(fileType),
      );
    }

    return FutureBuilder<ui.Image>(
      future: _decodeImage(thumbnail!),
      builder: (context, snapshot) {
        final image = snapshot.data;
        final isPortrait = image != null && image.width < image.height;
        final aspectRatio = isPortrait ? 3 / 4 : 16 / 9;

        return _buildCard(
          context,
          aspectRatio: aspectRatio,
          child: image == null
              ? Container(color: Colors.grey[850]) // brief decode placeholder
              : Image.memory(thumbnail!, fit: BoxFit.cover),
        );
      },
    );
  }

  Future<ui.Image> _decodeImage(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }

  Widget _buildCard(
    BuildContext context, {
    required double aspectRatio,
    required Widget child,
  }) {
    return Padding(
      padding: kPagePadding,
      child: GestureDetector(
        onTap: onTap,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: child,
                ),
              ),
              if (onTap != null)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.open_in_full,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
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
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
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
              note.author.isNotEmpty ? note.author[0].toUpperCase() : '?',
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

/// Bottom action row — Option A.
///
/// Favorite/Save now live in the AppBar (see NotePreviewPage), so this
/// row only holds the two "do something with the file" actions:
/// Open Note (primary, most width) and Download (compact, secondary).
/// They sit on one row instead of stacked, so there's no
/// "buttons above buttons" feeling.
class _ActionRow extends StatelessWidget {
  final NoteItem note;
  const _ActionRow(this.note);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
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
                foregroundColor: Colors.white,
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
          const SizedBox(width: 12),
          // Download is a one-off action, not a toggle, so it gets a
          // compact icon-only ghost button rather than a full-width
          // pill matching Favorite/Save's old treatment.
          SizedBox(
            height: 52,
            width: 52,
            child: OutlinedButton(
              onPressed: () {
                FileOpener.downloadFileWithProgress(
                  context,
                  note.fileUrl,
                  '${note.title}.${note.fileType}',
                );
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: BorderSide(color: Colors.grey[700]!),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Icon(Icons.download, color: Colors.white70),
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