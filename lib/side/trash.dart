import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/thumbnail/note_thumbnail.dart';
import '../backend/thumbnail/note_thumbnail_cache.dart';
import '../backend/thumbnail/note_thumbnail_generator.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class TrashPage extends StatefulWidget {
  const TrashPage({super.key});

  @override
  State<TrashPage> createState() => _TrashPageState();
}

class _TrashPageState extends State<TrashPage> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool isGridView = false;
  String sortBy = "Last Deleted (Recent)";
  List<Map<String, dynamic>> _trashedNotes = [];

  @override
  void initState() {
    super.initState();
    _loadTrash();
  }

  Future<void> _loadTrash() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final response = await _supabase
          .from('notes')
          .select()
          .eq('user_id', user.id)
          .filter('deleted_at', 'not.is', null)
          .order('deleted_at', ascending: false);

      setState(() {
        _trashedNotes = List<Map<String, dynamic>>.from(response as List);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load trash: $e')));
      }
    }
  }

  Future<void> _restoreNote(String noteId) async {
    await _supabase
        .from('notes')
        .update({'deleted_at': null, 'delete_expires_at': null})
        .eq('id', noteId);

    await _loadTrash();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Note restored')));
    }
  }

  Future<void> _deleteForever(String noteId, String fileUrl) async {
    try {
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      final bucketIndex = segments.indexOf('notes');
      final path = segments.sublist(bucketIndex + 1).join('/');

      await _supabase.storage.from('notes').remove([path]);
      await _supabase.from('notes').delete().eq('id', noteId);

      await _loadTrash();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note permanently deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
      }
    }
  }

  int _daysRemaining(String expiresAt) {
    final expiry = DateTime.parse(expiresAt).toLocal();
    return expiry.difference(DateTime.now()).inDays;
  }

  void _sortItems(List<Map<String, dynamic>> items) {
    switch (sortBy) {
      case "Last Deleted (Recent)":
        items.sort(
          (a, b) => DateTime.parse(
            b['deleted_at'],
          ).compareTo(DateTime.parse(a['deleted_at'])),
        );
        break;
      case "Last Deleted (Oldest)":
        items.sort(
          (a, b) => DateTime.parse(
            a['deleted_at'],
          ).compareTo(DateTime.parse(b['deleted_at'])),
        );
        break;
      case "Alphabetical":
        items.sort((a, b) => (a['title'] ?? '').compareTo(b['title'] ?? ''));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final textScale = width < 360 ? 0.9 : 1.0;
    final iconSize = width < 360 ? 20.0 : 24.0;
    final padding = width < 360 ? 12.0 : 16.0;

    List<Map<String, dynamic>> sortedItems = List.from(_trashedNotes);
    _sortItems(sortedItems);

    return Scaffold(
      backgroundColor: kDarkSurface,
      appBar: AppBar(
        backgroundColor: kDarkSurface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Trash',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18 * textScale,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body:
          _isLoading
              ? const Center(
                child: CircularProgressIndicator(color: kPrimaryColor),
              )
              : Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: padding / 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _showSortOptions,
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    sortBy,
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 16 * textScale,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_down,
                                  color: Colors.white70,
                                ),
                              ],
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            isGridView ? Icons.list : Icons.grid_view,
                            color: Colors.white70,
                            size: iconSize,
                          ),
                          onPressed: () {
                            setState(() {
                              isGridView = !isGridView;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        _trashedNotes.isEmpty
                            ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    size: 64,
                                    color: Colors.grey[600],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Trash is empty',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Deleted notes will appear here',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            )
                            : RefreshIndicator(
                              color: kPrimaryColor,
                              onRefresh: _loadTrash,
                              child:
                                  isGridView
                                      ? _buildGridView(sortedItems, width)
                                      : _buildListView(
                                        sortedItems,
                                        textScale,
                                        iconSize,
                                      ),
                            ),
                  ),
                ],
              ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sortOption("Last Deleted (Recent)"),
                _sortOption("Last Deleted (Oldest)"),
                _sortOption("Alphabetical"),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _sortOption(String option) {
    final isSelected = sortBy == option;
    return ListTile(
      title: Text(
        option,
        style: TextStyle(
          color: isSelected ? kPrimaryColor : Colors.white,
          fontSize: 16,
        ),
      ),
      trailing:
          isSelected ? const Icon(Icons.check, color: kPrimaryColor) : null,
      onTap: () {
        setState(() {
          sortBy = option;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildGridView(List<Map<String, dynamic>> items, double width) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final note = items[index];
        final days =
            note['delete_expires_at'] == null
                ? 0
                : _daysRemaining(note['delete_expires_at']);
        return TrashGridItemWidget(
          note: note,
          daysRemaining: days,
          onMenuTap: () => _showItemMenu(note),
        );
      },
    );
  }

  Widget _buildListView(
    List<Map<String, dynamic>> items,
    double textScale,
    double iconSize,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final note = items[index];
        final days =
            note['delete_expires_at'] == null
                ? 0
                : _daysRemaining(note['delete_expires_at']);
        return TrashItemWidget(
          note: note,
          daysRemaining: days,
          onMenuTap: () => _showItemMenu(note),
          textScale: textScale,
          iconSize: iconSize,
        );
      },
    );
  }

  Widget _buildOption(
    BuildContext context,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? Colors.red : Colors.white),
      title: Text(
        label,
        style: TextStyle(
          color: isDestructive ? Colors.red : Colors.white,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showItemMenu(Map<String, dynamic> note) {
    showModalBottomSheet(
      backgroundColor: kCardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      context: context,
      builder:
          (context) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildOption(context, Icons.restore, "Restore", () {
                  Navigator.pop(context);
                  _restoreNote(note['id']);
                }),
                const Divider(color: Colors.grey),
                _buildOption(
                  context,
                  Icons.delete_forever,
                  "Delete Forever",
                  () {
                    Navigator.pop(context);
                    _showDeleteConfirmation(note);
                  },
                  isDestructive: true,
                ),
              ],
            ),
          ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> note) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: kCardColor,
            title: const Text(
              'Delete Forever',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to permanently delete this note? This action cannot be undone.',
              style: TextStyle(color: Colors.grey),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteForever(note['id'], note['file_url']);
                },
                child: const Text(
                  'Delete Forever',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }
}

// Grid Item Widget
class TrashGridItemWidget extends StatelessWidget {
  final Map<String, dynamic> note;
  final int daysRemaining;
  final VoidCallback onMenuTap;

  const TrashGridItemWidget({
    super.key,
    required this.note,
    required this.daysRemaining,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getColor().withOpacity(0.3),
                          _getColor().withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  _buildLockedPreview(),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: _getColor(),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Icon(_getIcon(), color: Colors.white, size: 12),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        note['title'] ?? 'Untitled',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: onMenuTap,
                      child: Icon(
                        Icons.more_vert,
                        color: Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Deletes in $daysRemaining day${daysRemaining != 1 ? 's' : ''}",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockedPreview() {
    return Stack(
      children: [
        NoteThumbnailWithCache(
          noteId: note['id'],
          fileUrl: note['file_url'],
          fileType: note['file_type'],
        ),
        Container(
          decoration: BoxDecoration(color: Colors.black.withOpacity(0.35)),
          alignment: Alignment.center,
          child: const Icon(
            Icons.lock_outline,
            color: Colors.white70,
            size: 28,
          ),
        ),
      ],
    );
  }

  Color _getColor() {
    final fileType = note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Colors.red[300]!;
      case 'docx':
        return Colors.blue[300]!;
      default:
        return kPrimaryColor;
    }
  }

  IconData _getIcon() {
    final fileType = note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

// List Item Widget
class TrashItemWidget extends StatelessWidget {
  final Map<String, dynamic> note;
  final int daysRemaining;
  final VoidCallback onMenuTap;
  final double textScale;
  final double iconSize;

  const TrashItemWidget({
    super.key,
    required this.note,
    required this.daysRemaining,
    required this.onMenuTap,
    required this.textScale,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!, width: 1),
              ),
              child: Icon(_getIcon(), color: _getColor(), size: iconSize + 4),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    note['title'] ?? 'Untitled',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16 * textScale,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Deletes in $daysRemaining day${daysRemaining != 1 ? 's' : ''}",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 13 * textScale,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: Colors.grey[400],
                size: iconSize,
              ),
              onPressed: onMenuTap,
            ),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    final fileType = note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Colors.red[300]!;
      case 'docx':
        return Colors.blue[300]!;
      default:
        return kPrimaryColor;
    }
  }

  IconData _getIcon() {
    final fileType = note['file_type']?.toLowerCase();
    switch (fileType) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
        return Icons.description;
      default:
        return Icons.insert_drive_file;
    }
  }
}

// Thumbnail with cache
class NoteThumbnailWithCache extends StatefulWidget {
  final String noteId;
  final String fileUrl;
  final String fileType;

  const NoteThumbnailWithCache({
    super.key,
    required this.noteId,
    required this.fileUrl,
    required this.fileType,
  });

  @override
  State<NoteThumbnailWithCache> createState() => _NoteThumbnailWithCacheState();
}

class _NoteThumbnailWithCacheState extends State<NoteThumbnailWithCache> {
  Uint8List? _pdf;
  String? _docx;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _pdf = NoteThumbnailCache.getPdf(widget.noteId);
    _docx = NoteThumbnailCache.getDocx(widget.noteId);

    if (_pdf != null || _docx != null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      if (widget.fileType.toLowerCase() == 'pdf') {
        final bytes = await generatePdfThumbnail(widget.fileUrl);
        if (!mounted) return;
        NoteThumbnailCache.setPdf(widget.noteId, bytes);
        _pdf = bytes;
      } else if (widget.fileType.toLowerCase() == 'docx') {
        final text = await generateDocxPreview(widget.fileUrl);
        if (!mounted) return;
        NoteThumbnailCache.setDocx(widget.noteId, text);
        _docx = text;
      }
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Trash thumbnail error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return NoteThumbnail(
      noteId: widget.noteId,
      fileType: widget.fileType,
      pdfThumbnail: _pdf,
      docxPreviewText: _docx,
    );
  }
}
