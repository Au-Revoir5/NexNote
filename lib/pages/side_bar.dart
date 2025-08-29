import 'package:flutter/material.dart';
import 'favorites.dart';

class SideBar extends StatelessWidget {
  final Function(int)? onNavigate;
  const SideBar({super.key, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1C1C1E), // Match your app's dark theme
            ),
            child: Row(
              children: [
                // Profile Picture
                Container(
                  height: 60,
                  width: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(30),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      "PFP",
                      style: TextStyle(color: Colors.black, fontSize: 20),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                // Info + Pencil in a Row
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Your Name",
                              style: TextStyle(color: Colors.white, fontSize: 14),
                            ),
                            Text(
                              "placeholder@email.com",
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Icon(
                          Icons.edit,
                          color: Colors.white70,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context); // Close drawer
              onNavigate?.call(0); // Navigate to Home tab (index 0)
            },
            leading: Icon(Icons.home, color: Colors.white),
            title: Text("Home", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context); // Close drawer
              onNavigate?.call(4); // Navigate to Notes tab (index 4)
            },
            leading: Icon(Icons.note, color: Colors.white),
            title: Text("My Notes", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesPage()),
              );
            },
            leading: Icon(Icons.star, color: Colors.white),
            title: Text("My Favorites", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context); // Close drawer
              // Navigate to settings page or show settings dialog
              _showSettingsDialog(context);
            },
            leading: Icon(Icons.settings, color: Colors.white),
            title: Text("Settings", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
          ListTile(
            onTap: () {
              Navigator.pop(context); // Close drawer
              _showLogoutDialog(context);
            },
            leading: Icon(Icons.logout, color: Colors.white),
            title: Text("Log Out", style: TextStyle(color: Colors.white, fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2C2C2E),
        title: Text("Settings", style: TextStyle(color: Colors.white)),
        content: Text("Settings page coming soon!", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("OK", style: TextStyle(color: Color(0xFF6366F1))),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Color(0xFF2C2C2E),
        title: Text("Log Out", style: TextStyle(color: Colors.white)),
        content: Text("Are you sure you want to log out?", style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Add your logout logic here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Logged out successfully!")),
              );
            },
            child: Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}