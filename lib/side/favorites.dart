import 'package:flutter/material.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String sortBy = "Last Edited (Recent)";
  bool isGridView = false;

  final List<FavoriteItem> favoriteItems = [
    FavoriteItem(title: "Integral", lastEdited: "2 days ago"),
    FavoriteItem(title: "Limit tak hingga", lastEdited: "5 days ago"),
    FavoriteItem(title: "Matrix", lastEdited: "15 days ago"),
  ];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Adjust based on screen width (phones only)
    final textScale = width < 360 ? 0.9 : 1.0;
    final iconSize = width < 360 ? 20.0 : 24.0;
    final padding = width < 360 ? 12.0 : 16.0;

    List<FavoriteItem> sortedItems = List.from(favoriteItems);
    _sortItems(sortedItems);

    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white, size: iconSize),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Favorite",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18 * textScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white, size: iconSize),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                EdgeInsets.symmetric(horizontal: padding, vertical: padding / 2),
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
                        const Icon(Icons.keyboard_arrow_down,
                            color: Colors.white70),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isGridView ? Icons.grid_view : Icons.list,
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
            child: isGridView
                ? _buildGridView(sortedItems, width)
                : _buildListView(sortedItems, textScale, iconSize),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
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
                _sortOption("Last Edited (Recent)"),
                _sortOption("Last Edited (Oldest)"),
                _sortOption("Alphabetical"),
              ],
            ),
          ),
        );
      },
    );
  }

  void _sortItems(List<FavoriteItem> items) {
    switch (sortBy) {
      case "Last Edited (Recent)":
        items.sort((a, b) => _extractDays(a.lastEdited)
            .compareTo(_extractDays(b.lastEdited)));
        break;
      case "Last Edited (Oldest)":
        items.sort((a, b) => _extractDays(b.lastEdited)
            .compareTo(_extractDays(a.lastEdited)));
        break;
      case "Alphabetical":
        items.sort((a, b) => a.title.compareTo(b.title));
        break;
    }
  }

  int _extractDays(String text) {
    final match = RegExp(r'(\d+)').firstMatch(text);
    return match != null ? int.parse(match.group(1)!) : 0;
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
      trailing: isSelected
          ? const Icon(Icons.check, color: kPrimaryColor)
          : null,
      onTap: () {
        setState(() {
          sortBy = option;
        });
        Navigator.pop(context);
      },
    );
  }

  Widget _buildGridView(List<FavoriteItem> items, double width) {
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
        return FavoriteGridItemWidget(
          item: items[index],
          onTap: () => print("Tapped ${items[index].title}"),
          onMenuTap: () => _showItemMenu(items[index]),
        );
      },
    );
  }


  Widget _buildListView(
      List<FavoriteItem> items, double textScale, double iconSize) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return FavoriteItemWidget(
          item: items[index],
          onTap: () => print("Tapped ${items[index].title}"),
          onMenuTap: () => _showItemMenu(items[index]),
          textScale: textScale,
          iconSize: iconSize,
        );
      },
    );
  }

  void _showItemMenu(FavoriteItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF2C2C2E),
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
                ListTile(
                  leading: const Icon(Icons.edit, color: Colors.white),
                  title:
                      const Text("Edit", style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.share, color: Colors.white),
                  title: const Text("Share",
                      style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading:
                      const Icon(Icons.favorite_border, color: Colors.white),
                  title: const Text("Remove from Favorites",
                      style: TextStyle(color: Colors.white)),
                  onTap: () => Navigator.pop(context),
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title:
                      const Text("Delete", style: TextStyle(color: Colors.red)),
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// -------------------
/// Helper Classes
/// -------------------

class FavoriteItem {
  final String title;
  final String lastEdited;

  FavoriteItem({required this.title, required this.lastEdited});
}

class FavoriteGridItemWidget extends StatelessWidget {
  final FavoriteItem item;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const FavoriteGridItemWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getColor().withOpacity(0.3),
                      _getColor().withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Icon(_getIcon(), color: _getColor(), size: 36),
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
                        child: const Icon(Icons.bookmark,
                            color: Colors.white, size: 12),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
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
                        child: Icon(Icons.more_vert,
                            color: Colors.grey[400], size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Last edited ${item.lastEdited}",
                    style:
                        TextStyle(color: Colors.grey[500], fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getColor() {
    switch (item.title) {
      case "Integral":
        return Colors.blue[300]!;
      case "Limit tak hingga":
        return Colors.green[300]!;
      case "Matrix":
        return Colors.orange[300]!;
      default:
        return Colors.grey[400]!;
    }
  }

  IconData _getIcon() {
    switch (item.title) {
      case "Integral":
        return Icons.functions;
      case "Limit tak hingga":
        return Icons.trending_up;
      case "Matrix":
        return Icons.grid_on;
      default:
        return Icons.description;
    }
  }
}

class FavoriteItemWidget extends StatelessWidget {
  final FavoriteItem item;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final double textScale;
  final double iconSize;

  const FavoriteItemWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.onMenuTap,
    required this.textScale,
    required this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
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
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 1,
                  ),
                ),
                child: Icon(_getIcon(), color: _getColor(), size: iconSize + 4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16 * textScale,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "Last edited ${item.lastEdited}",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 13 * textScale,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.more_vert,
                    color: Colors.grey[400], size: iconSize),
                onPressed: onMenuTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getColor() {
    switch (item.title) {
      case "Integral":
        return Colors.blue[300]!;
      case "Limit tak hingga":
        return Colors.green[300]!;
      case "Matrix":
        return Colors.orange[300]!;
      default:
        return Colors.grey[400]!;
    }
  }

  IconData _getIcon() {
    switch (item.title) {
      case "Integral":
        return Icons.functions;
      case "Limit tak hingga":
        return Icons.trending_up;
      case "Matrix":
        return Icons.grid_on;
      default:
        return Icons.description;
    }
  }
}