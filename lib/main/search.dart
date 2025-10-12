import 'package:flutter/material.dart';

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

  String sortBy = "Last Edited (Recent)";

  final List<NoteItem> notes = [
    NoteItem(
      title: 'Placeholder Subject A',
      author: 'Made by User1',
      color: Colors.orange.shade100,
      textColor: Colors.black,
    ),
    NoteItem(
      title: 'Placeholder Topic B',
      author: 'Made by User2',
      color: Colors.blue.shade50,
      textColor: Colors.black,
    ),
    NoteItem(
      title: 'Placeholder Course C',
      author: 'Made by User3',
      color: Colors.green.shade100,
      textColor: Colors.black,
    ),
    NoteItem(
      title: 'Placeholder Module D',
      author: 'Made by User4',
      color: Colors.purple.shade50,
      textColor: Colors.black,
    ),
    NoteItem(
      title: 'Placeholder Chapter E',
      author: 'Made by User5',
      color: Colors.pink.shade100,
      textColor: Colors.black,
    ),
    NoteItem(
      title: 'Placeholder Unit F',
      author: 'Made by User6',
      color: Colors.yellow.shade100,
      textColor: Colors.black,
    ),
  ];

  // --- Sort Logic ---
  void _sortNotes() {
    setState(() {
      if (sortBy == "A–Z") {
        notes.sort((a, b) => a.title.compareTo(b.title));
      } else if (sortBy == "Z–A") {
        notes.sort((a, b) => b.title.compareTo(a.title));
      } else if (sortBy == "Last Edited (Old)") {
        notes.shuffle(); // placeholder behavior
      } else {
        notes.shuffle(); // placeholder for "Recent"
      }
    });
  }

  // --- Show Sort Sheet ---
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

  // --- Sort Option Widget ---
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
        Navigator.pop(context); // close sheet
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
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
                                onChanged: (value) {
                                  setState(() {});
                                },
                                style: TextStyle(
                                  color: _searchController.text.isEmpty
                                      ? Colors.black.withOpacity(0.5)
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

                    // Notes Grid
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: notes.length,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.8,
                        ),
                        itemBuilder: (context, index) {
                          return NoteCard(note: notes[index]);
                        },
                      ),
                    ),
                  ],
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
  final String title;
  final String author;
  final Color color;
  final Color textColor;

  NoteItem({
    required this.title,
    required this.author,
    required this.color,
    required this.textColor,
  });
}

// --- Note Card Widget ---
class NoteCard extends StatelessWidget {
  final NoteItem note;

  const NoteCard({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: note.color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
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
                    margin: const EdgeInsets.only(bottom: 8)),
                Container(
                    width: 120,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 8)),
                Container(
                    width: 100,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 12)),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black26),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Center(
                    child: Text(
                      'IMG',
                      style: TextStyle(fontSize: 10, color: Colors.black54),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                    width: double.infinity,
                    height: 2,
                    color: Colors.black26,
                    margin: const EdgeInsets.only(bottom: 4)),
                Container(width: 80, height: 2, color: Colors.black26),
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
                color: Colors.black.withOpacity(0.7),
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
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(127, 0, 0, 0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.more_vert,
                  color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
