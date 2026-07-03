import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend/SupabaseHomeNotesProvider.dart';
import '../backend/thumbnail/note_thumbnail.dart';
import '../backend/thumbnail/note_thumbnail_cache.dart';
import '../backend/thumbnail/note_thumbnail_generator.dart';
import '../backend/file_opener.dart';
import 'dart:typed_data';
import '../side/preview.dart';
import '../main/search.dart' show NoteItem;
import '../side/favorites.dart';


// Constants for reuse
const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class NotePreview {
  final String id;
  final String title;
  final DateTime updatedAt;
  final bool isPublic;
  final String fileUrl;
  final String fileType;
  final String? authorAvatar;
  final String authorName;

  const NotePreview({
    required this.id,
    required this.title,
    required this.updatedAt,
    required this.isPublic,
    required this.fileUrl,
    required this.fileType,
    required this.authorName,
    this.authorAvatar,
  });

}

abstract class HomeNotesProvider {
  Future<List<NotePreview>> communityNotes();
  Future<List<NotePreview>> recentNotes();
  Future<List<NotePreview>> favoriteNotes();
}


// -------------------------------------------------------------
// HomePage Widget Wrapper
// -------------------------------------------------------------
class HomePage extends StatefulWidget {
  final void Function(int index, {bool autoFocusSearch})? onTabRequest;

  const HomePage({super.key, this.onTabRequest});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
  with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _characterCount;
  late final HomeNotesProvider provider = SupabaseHomeNotesProvider();
  late Future<List<NotePreview>> _recentFuture = Future.value([]);
  late Future<List<NotePreview>> _communityFuture = Future.value([]);
  late Future<List<NotePreview>> _favoritesFuture = Future.value([]);
  String _username = "User";

  String get _fullText => "Welcome $_username!";

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _loadUsername();

    _communityFuture = provider.communityNotes();
    _recentFuture = provider.recentNotes();
    _favoritesFuture = provider.favoriteNotes();
  }



  String _timeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  Widget _horizontalLoader() {
    return const SizedBox(
      height: 180,
      child: Center(
        child: CircularProgressIndicator(color: kPrimaryColor),
      ),
    );
  }

  Widget _emptyState(String text) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(text, style: const TextStyle(color: Colors.grey))),
    );
  }


  void _setupAnimation() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1750),
      vsync: this,
    );

    _characterCount = StepTween(
      begin: 0,
      end: _fullText.length,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  

  // -------------------------------------------------------------
  // Fetch username from Supabase
  // -------------------------------------------------------------
  Future<void> _loadUsername() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) return;

    final res = await supabase
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .single();

    final loadedUsername = res['username'] ?? "User";

    setState(() {
      _username = loadedUsername;

      // rebuild animation with correct text length
      _characterCount = StepTween(
        begin: 0,
        end: _fullText.length,
      ).animate(
        CurvedAnimation(
          parent: _animationController,
          curve: Curves.easeInOut,
        ),
      );
    });

    // restart animation from scratch
    _animationController.forward(from: 0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // -------------------------------------------------------------
  // Animated TextSpan Builder (Dynamic username color)
  // -------------------------------------------------------------
  List<TextSpan> _buildAnimatedTextSpans(String animatedText) {

    final welcomePrefix = "Welcome ";

    if (animatedText.isEmpty) return [];

    // Still typing "Welcome "
    if (animatedText.length <= welcomePrefix.length) {
      return [
        TextSpan(
          text: animatedText,
          style: TextStyle(color: Colors.white),
        )
      ];
    }

    // "Welcome " finished, add it as white
    final spans = <TextSpan>[
      TextSpan(
        text: welcomePrefix,
        style: TextStyle(color: Colors.white),
      ),
    ];

    final nameStart = welcomePrefix.length;
    final remaining = animatedText.length > nameStart
        ? animatedText.substring(nameStart)
        : '';

    spans.add(TextSpan(
      text: remaining,
      style: TextStyle(color: kPrimaryColor),
    ));

    return spans;
  }
  

  // -------------------------------------------------------------
  // UI
  // -------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      body: RefreshIndicator(
      color: kPrimaryColor,
      onRefresh: () async {
        setState(() {
          _communityFuture = provider.communityNotes();
          _recentFuture = provider.recentNotes();
          _favoritesFuture = provider.favoriteNotes();
        });
      },
      child: SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
            AnimatedBuilder(
              animation: _characterCount,
              builder: (context, child) {
                final animatedText = _fullText.substring(0, _characterCount.value);
                final showCursor = _characterCount.value < _fullText.length;

                return RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    children: [
                      ..._buildAnimatedTextSpans(animatedText),
                      if (showCursor)
                        const TextSpan(
                          text: '|',
                          style: TextStyle(color: Colors.white),
                        ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: 8),
            Text(
              'What would you like to do with\nyour notes today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPrimaryColor,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            SizedBox(height: 32),

            // ---------------- Explore notes banner ----------------
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: kAccentYellow, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Explore public lecture notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            // ---------------- Search ----------------
            GestureDetector(
              onTap: () {
                widget.onTabRequest?.call(1, autoFocusSearch: true);// Search tab
              },
              child: Hero(
                tag: 'search-bar',
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: Colors.grey[600], size: 20),
                      const SizedBox(width: 8),
                      Text('Search notes...', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 24),

            // ---------------- Community Notes ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Community Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    widget.onTabRequest?.call(1, autoFocusSearch: false);// Search
                  },
                  child: const Text(
                    'View All >',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),


            SizedBox(height: 16),

            FutureBuilder<List<NotePreview>>(
              future: _communityFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _horizontalLoader();
                }

                final data = snapshot.data ?? [];
                if (data.isEmpty) {
                  return _emptyState("No community notes yet");
                }

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.length.clamp(0, 6),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, i) {
                    final note = data[i];
                    return _CommunityGridCard(note: note);
                  },
                );
              },
            ),


            SizedBox(height: 32),

            // ---------------- Recent Notes ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                  GestureDetector(
                    onTap: () {
                     widget.onTabRequest?.call(4); // Files page
                    },
                    child: const Text(
                      'View All >',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 16),
            FutureBuilder<List<NotePreview>>(
  future: _recentFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _horizontalLoader();
    }

    final data = (snapshot.data ?? []).take(2).toList();
    if (data.isEmpty) {
      return _emptyState("No recent notes");
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final twoCardWidth = (screenWidth - 40 - 12) / 2;

    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _HorizontalNoteCard(
          note: data[i],
          width: twoCardWidth,
          timeAgo: _timeAgo,
        ),
      ),
    );
  },
),


            SizedBox(height: 32),

            // ---------------- My Favorites ----------------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'My Favorites',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
               GestureDetector(
                 onTap: () {
                    Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                              builder: (context) => FavoritesPage()),
                                        );
                  },
                  child: const Text(
                    'View All >',
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            FutureBuilder<List<NotePreview>>(
  future: _favoritesFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return _horizontalLoader();
    }

    final data = (snapshot.data ?? []).take(2).toList();
    if (data.isEmpty) {
      return _emptyState("No favorite notes");
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final twoCardWidth = (screenWidth - 40 - 12) / 2;

    return SizedBox(
      height: 180, 
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) => _HorizontalNoteCard(
          note: data[i],
          width: twoCardWidth,
          timeAgo: _timeAgo,
        ),
      ),
    );
  },
),


            SizedBox(height: 20),
          ],
        ),
      ),
      )
    );
  }
}

// -------------------------------------------------------------
// UI COMPONENTS
// -------------------------------------------------------------
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

class _HorizontalNoteCard extends StatelessWidget {
  final NotePreview note;
  final double width;
  final String Function(DateTime) timeAgo;

  const _HorizontalNoteCard({
    required this.note,
    required this.width,
    required this.timeAgo,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          FileOpener.openFile(
            context,
            note.fileUrl,
            '${note.title}.${note.fileType}',
          );
        },
        child: Container(
          decoration: BoxDecoration(
            color: kCardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 110,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: NoteThumbnailWithCache(
                    noteId: note.id,
                    fileUrl: note.fileUrl,
                    fileType: note.fileType,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last edited ${timeAgo(note.updatedAt)}",
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    // 1) cache first
    _pdf = NoteThumbnailCache.getPdf(widget.noteId);
    _docx = NoteThumbnailCache.getDocx(widget.noteId);

    if (_pdf != null || _docx != null) {
      if (mounted) setState(() {});
      return;
    }

    try {
      final type = widget.fileType.toLowerCase();

      if (type == 'pdf') {
        final bytes = await generatePdfThumbnail(widget.fileUrl);
        if (!mounted) return;
        NoteThumbnailCache.setPdf(widget.noteId, bytes);
        _pdf = bytes;
      } else if (type == 'docx') {
        final text = await generateDocxPreview(widget.fileUrl);
        if (!mounted) return;
        NoteThumbnailCache.setDocx(widget.noteId, text);
        _docx = text;
      }

      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Thumbnail load error: $e');
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

  NoteItem _communityToNoteItem(NotePreview note) {
    return NoteItem(
      id: note.id,
      title: note.title.isNotEmpty ? note.title : 'Untitled',
      description: '',
      fileUrl: note.fileUrl,
      fileType: note.fileType,
      updatedAt: note.updatedAt,
      createdAt: note.updatedAt,
      tags: const [],
      author: note.authorName,
    );
  }


 class _CommunityGridCard extends StatelessWidget {
  final NotePreview note;

  const _CommunityGridCard({required this.note});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () async {
        // Try to reuse cached thumbnails
        final pdfThumb = NoteThumbnailCache.getPdf(note.id);
        final docxPreview = NoteThumbnailCache.getDocx(note.id);

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => NotePreviewPage(
              note: _communityToNoteItem(note),
              pdfThumbnail: pdfThumb,
              docxPreviewText: docxPreview,
              pdfBytes: null, // load fullscreen later if needed
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Positioned.fill(
              child: NoteThumbnailWithCache(
                noteId: note.id,
                fileUrl: note.fileUrl,
                fileType: note.fileType,
              ),
            ),

            // Author avatar
            Positioned(
              left: 8,
              bottom: 8,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: const Icon(
                  Icons.person,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
