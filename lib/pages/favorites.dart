import 'package:flutter/material.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  _FavoritesPageState createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  String sortBy = "Last Edited (Recent)";
  bool isGridView = false;
  
  final List<FavoriteItem> favoriteItems = [
    FavoriteItem(
      title: "Integral",
      lastEdited: "2 days ago",
      thumbnail: "assets/integral_thumb.png",
    ),
    FavoriteItem(
      title: "Limit tak hingga",
      lastEdited: "5 days ago",
      thumbnail: "assets/limit_thumb.png",
    ),
    FavoriteItem(
      title: "Matrix",
      lastEdited: "15 days ago",
      thumbnail: "assets/matrix_thumb.png",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: Color(0xFF1C1C1E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "My Favorite",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.search, color: Colors.white),
            onPressed: () {
              // Implement search functionality
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Sort dropdown
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showSortOptions(),
                    child: Row(
                      children: [
                        Text(
                          sortBy,
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isGridView ? Icons.list : Icons.list, 
                    color: Colors.white70
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
          
          // Favorites list/grid
          Expanded(
            child: isGridView ? _buildGridView() : _buildListView(),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _sortOption("Last Edited (Recent)"),
              _sortOption("Last Edited (Oldest)"),
              _sortOption("Alphabetical"),
              _sortOption("Date Created"),
            ],
          ),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16),
      itemCount: favoriteItems.length,
      itemBuilder: (context, index) {
        return FavoriteItemWidget(
          item: favoriteItems[index],
          onTap: () {
            // Handle item tap
            print("Tapped on ${favoriteItems[index].title}");
          },
          onMenuTap: () => _showItemMenu(favoriteItems[index]),
        );
      },
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: favoriteItems.length,
      itemBuilder: (context, index) {
        return FavoriteGridItemWidget(
          item: favoriteItems[index],
          onTap: () {
            print("Tapped on ${favoriteItems[index].title}");
          },
          onMenuTap: () => _showItemMenu(favoriteItems[index]),
        );
      },
    );
  }

  Widget _sortOption(String option) {
    return ListTile(
      title: Text(
        option,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16,
        ),
      ),
      trailing: sortBy == option
          ? Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() {
          sortBy = option;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showItemMenu(FavoriteItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF2C2C2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.edit, color: Colors.white),
                title: Text("Edit", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Handle edit
                },
              ),
              ListTile(
                leading: Icon(Icons.share, color: Colors.white),
                title: Text("Share", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Handle share
                },
              ),
              ListTile(
                leading: Icon(Icons.favorite_border, color: Colors.white),
                title: Text("Remove from Favorites", style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  // Handle remove from favorites
                },
              ),
              ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text("Delete", style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  // Handle delete
                },
              ),
            ],
          ),
        );
      },
    );
  }
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
        color: Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisSize: MainAxisSize.min, // 👈 shrink card to fit content
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail section
            AspectRatio(
              aspectRatio: 16 / 9, // 👈 consistent squished thumbnail
              child: ClipRRect(
                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                child: _buildThumbnail(),
              ),
            ),

            // Content section
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _getCategoryColor(),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Icon(
                          _getCategoryIcon(),
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
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
                  SizedBox(height: 4),
                  Text(
                    "Last edited ${item.lastEdited}",
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
    );
  }


  Widget _buildThumbnail() {
    Color thumbnailColor;
    IconData thumbnailIcon;
    
    switch (item.title) {
      case "Integral":
        thumbnailColor = Colors.blue[300]!;
        thumbnailIcon = Icons.functions;
        break;
      case "Limit tak hingga":
        thumbnailColor = Colors.green[300]!;
        thumbnailIcon = Icons.trending_up;
        break;
      case "Matrix":
        thumbnailColor = Colors.orange[300]!;
        thumbnailIcon = Icons.grid_on;
        break;
      default:
        thumbnailColor = Colors.grey[600]!;
        thumbnailIcon = Icons.description;
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            thumbnailColor.withOpacity(0.3),
            thumbnailColor.withOpacity(0.1),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          thumbnailIcon,
          color: thumbnailColor,
          size: 40,
        ),
      ),
    );
  }
  
  Color _getCategoryColor() {
    switch (item.title) {
      case "Integral":
        return Colors.red;
      case "Limit tak hingga":
        return Colors.blue;
      case "Matrix":
        return Colors.white;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getCategoryIcon() {
    switch (item.title) {
      case "Integral":
        return Icons.integration_instructions;
      case "Limit tak hingga":
        return Icons.trending_up;
      case "Matrix":
        return Icons.border_all;
      default:
        return Icons.description;
    }
  }
}

class FavoriteItem {
  final String title;
  final String lastEdited;
  final String thumbnail;

  FavoriteItem({
    required this.title,
    required this.lastEdited,
    required this.thumbnail,
  });
}

class FavoriteItemWidget extends StatelessWidget {
  final FavoriteItem item;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;

  const FavoriteItemWidget({
    super.key,
    required this.item,
    required this.onTap,
    required this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[700]!,
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _buildThumbnail(),
                ),
              ),
              
              SizedBox(width: 12),
              
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      "Last edited ${item.lastEdited}",
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Menu button
              IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Colors.grey[400],
                ),
                onPressed: onMenuTap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail() {
    // Since we can't load actual images in this example,
    // we'll create placeholder thumbnails with different colors
    Color thumbnailColor;
    IconData thumbnailIcon;
    
    switch (item.title) {
      case "Integral":
        thumbnailColor = Colors.blue[300]!;
        thumbnailIcon = Icons.functions;
        break;
      case "Limit tak hingga":
        thumbnailColor = Colors.green[300]!;
        thumbnailIcon = Icons.trending_up;
        break;
      case "Matrix":
        thumbnailColor = Colors.orange[300]!;
        thumbnailIcon = Icons.grid_on;
        break;
      default:
        thumbnailColor = Colors.grey[600]!;
        thumbnailIcon = Icons.description;
    }
    
    return Container(
      width: 60,
      height: 60,
      color: thumbnailColor.withOpacity(0.2),
      child: Icon(
        thumbnailIcon,
        color: thumbnailColor,
        size: 24,
      ),
    );
  }
}