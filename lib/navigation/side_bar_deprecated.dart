import 'package:flutter/material.dart';
import '../side/favorites.dart';
import '../side/settings.dart';
import '../landing/landing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
            decoration: BoxDecoration(color: Color(0xFF1C1C1E)),
            child: Row(
              children: [
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
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              "placeholder@email.com",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // HOME
          ListTile(
            onTap: () {
              Navigator.pop(context);
              onNavigate?.call(0);
            },
            leading: Icon(Icons.home, color: Colors.white),
            title: Text(
              "Home",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),

          // NOTES
          ListTile(
            onTap: () {
              Navigator.pop(context);
              onNavigate?.call(4);
            },
            leading: Icon(Icons.note, color: Colors.white),
            title: Text(
              "My Notes",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),

          // FAVORITES
          ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => FavoritesPage()),
              );
            },
            leading: Icon(Icons.star, color: Colors.white),
            title: Text(
              "My Favorites",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),

          // SETTINGS
          ListTile(
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsScreen()),
              );
            },
            leading: Icon(Icons.settings, color: Colors.white),
            title: Text(
              "Settings",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),

          // LOGOUT
          ListTile(
            onTap: () {
              // Capture a safe parent context BEFORE closing the drawer:
              final parentContext = context;

              // Close drawer first
              Navigator.pop(parentContext);

              // Wait until frame finishes (gives drawer animation time to finish)
              WidgetsBinding.instance.addPostFrameCallback((_) {
                // Show logout dialog using the parentContext
                _showLogoutDialog(parentContext);
              });
            },
            leading: Icon(Icons.logout, color: Colors.white),
            title: Text(
              "Log Out",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    // Capture a safe navigation context (root navigator)
    final nav = Navigator.of(context, rootNavigator: true);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Color(0xFF2C2C2E),
          title: Text("Log Out", style: TextStyle(color: Colors.white)),
          content: Text(
            "Are you sure you want to log out?",
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text("Cancel", style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // close dialog

                // Log out (no SnackBars!)
                await Supabase.instance.client.auth.signOut();

                // Navigate safely with rootNavigator
                nav.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => LandingPage()),
                  (route) => false,
                );
              },
              child: Text("Log Out", style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}
