import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _searchController = TextEditingController();
  
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Header (burger + profile)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu,
                    color: Colors.white,
                    size: 24,
                  ),
                  const Spacer(),
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: kCardColor,
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Area
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
                                decoration: const InputDecoration(
                                  hintText: 'Search',
                                  prefixIcon: Icon(Icons.search, color: Colors.grey),
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
                              onPressed: () {},
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
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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

class NoteCard extends StatelessWidget {
  final NoteItem note;

  const NoteCard({Key? key, required this.note}) : super(key: key);

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
          // Placeholder content to simulate handwritten notes
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Simulated handwritten lines
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
                
                // Placeholder diagrams/shapes
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
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                  ),
                ),
                
                const Spacer(),
                
                // More placeholder lines
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
          
          // Title and author at bottom
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
          
          // More options button
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              decoration: BoxDecoration(
                color: const Color.fromARGB(127, 0, 0, 0),
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
    );
  }
}