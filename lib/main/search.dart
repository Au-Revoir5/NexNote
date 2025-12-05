import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  final supabase = Supabase.instance.client;

  String sortBy = "Last Edited (Recent)";
  List<NoteItem> notes = [];
  List<NoteItem> filteredNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchPublicNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch public notes from Supabase
  Future<void> _fetchPublicNotes() async {
    try {
      setState(() {
        isLoading = true;
      });

      final response = await supabase
          .from('notes')
          .select('*, profiles(username, avatar_url)')
          .eq('is_public', true)
          .order('updated_at', ascending: false);

      final fetchedNotes = (response as List).map((note) {
        final username = note['profiles']?['username'] ?? 'Anonymous';
        return NoteItem(
          id: note['id'],
          title: note['title'] ?? 'Untitled',
          author: 'Made by $username',
          fileUrl: note['file_url'],
          fileType: note['file_type'],
          tags: List<String>.from(note['tags'] ?? []),
          createdAt: DateTime.parse(note['created_at']),
          updatedAt: DateTime.parse(note['updated_at']),
        );
      }).toList();

      setState(() {
        notes = fetchedNotes;
        filteredNotes = fetchedNotes;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading notes: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Filter notes based on search query
  void _filterNotes(String query) {
    setState(() {
      if (query.isEmpty) {
        filteredNotes = List.from(notes);
      } else {
        filteredNotes = notes.where((note) {
          final titleMatch = note.title.toLowerCase().contains(query.toLowerCase());
          final tagMatch = note.tags.any((tag) => tag.toLowerCase().contains(query.toLowerCase()));
          return titleMatch || tagMatch;
        }).toList();
      }
      _sortNotes();
    });
  }

  // Open file in browser/viewer
  Future<void> _openFile(String fileUrl, String title) async {
    try {
      final uri = Uri.parse(fileUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot open file'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Sort Logic
  void _sortNotes() {
    setState(() {
      if (sortBy == "A–Z") {
        filteredNotes.sort((a, b) => a.title.compareTo(b.title));
      } else if (sortBy == "Z–A") {
        filteredNotes.sort((a, b) => b.title.compareTo(a.title));
      } else if (sortBy == "Last Edited (Old)") {
        filteredNotes.sort((a, b) => a.updatedAt.compareTo(b.updatedAt));
      } else {
        // Last Edited (Recent)
        filteredNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      }
    });
  }

  // Show Sort Options
  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sortOption("Last Edited (Recent)"),
              _sortOption("Last Edited (Old)"),
              _sortOption("A–Z"),
              _sortOption("Z–A"),
            ],
          ),
        );
      },
    );
  }

  // Sort Option Widget
  Widget _sortOption(String label) {
    final isSelected = sortBy == label;

    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? kPrimaryColor : Colors.white,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(
              Icons.check,
              color: kPrimaryColor,
            )
          : null,
      onTap: () {
        setState(() {
          sortBy = label;
          _sortNotes();
        });
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDarkSurface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _fetchPublicNotes,
                color: kPrimaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Find Notes You Need',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '"Learning never exhausts the mind."',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            Text(
                              '~ Leonardo da Vinci',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Search and Filter Row
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: TextField(
                                  controller: _searchController,
                                  onChanged: _filterNotes,
                                  style: TextStyle(
                                    color: _searchController.text.isEmpty
                                        ? Colors.black.withValues(alpha: 0.5)
                                        : Colors.black,
                                    fontSize: 16,
                                  ),
                                  decoration: const InputDecoration(
                                    hintText: 'Search',
                                    hintStyle: TextStyle(color: Colors.grey),
                                    prefixIcon:
                                        Icon(Icons.search, color: Colors.grey),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 15,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: IconButton(
                                onPressed: () {},
                                icon: const Icon(Icons.tune, color: Colors.grey),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: IconButton(
                                onPressed: _showSortOptions,
                                icon: const Icon(Icons.sort, color: Colors.grey),
                                padding: const EdgeInsets.all(12),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Loading / Empty / Notes Grid
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: isLoading
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(32.0),
                                  child: CircularProgressIndicator(
                                    color: kPrimaryColor,
                                  ),
                                ),
                              )
                            : filteredNotes.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(32.0),
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 64,
                                            color: Colors.grey[600],
                                          ),
                                          const SizedBox(height: 16),
                                          Text(
                                            _searchController.text.isEmpty
                                                ? 'No public notes available'
                                                : 'No notes found',
                                            style: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : GridView.builder(
                                    shrinkWrap: true,
                                    physics: const NeverScrollableScrollPhysics(),
                                    itemCount: filteredNotes.length,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 12,
                                      mainAxisSpacing: 12,
                                      childAspectRatio: 0.8,
                                    ),
                                    itemBuilder: (context, index) {
                                      return NoteCard(
                                        note: filteredNotes[index],
                                        onTap: () => _openFile(
                                          filteredNotes[index].fileUrl,
                                          filteredNotes[index].title,
                                        ),
                                      );
                                    },
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
    );
  }
}

// --- Note Data Model ---
class NoteItem {
  final String id;
  final String title;
  final String author;
  final String fileUrl;
  final String fileType;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  NoteItem({
    required this.id,
    required this.title,
    required this.author,
    required this.fileUrl,
    required this.fileType,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  // Generate color based on file type
  Color get color {
    switch (fileType.toLowerCase()) {
      case 'pdf':
        return Colors.red.shade100;
      case 'docx':
        return Colors.blue.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color get textColor => Colors.black;
}

// --- Note Card Widget ---
class NoteCard extends StatelessWidget {
  final NoteItem note;
  final VoidCallback onTap;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: note.color,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    width: 120,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 8),
                  ),
                  Container(
                    width: 100,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 12),
                  ),
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Center(
                      child: Text(
                        note.fileType.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.black54,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 4),
                  ),
                  Container(
                    width: 80,
                    height: 2,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      note.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      note.author,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (note.tags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        children: note.tags.take(2).map((tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: kPrimaryColor.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tag,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.more_vert,
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
}