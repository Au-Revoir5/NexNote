import 'package:flutter/material.dart';
import 'side_bar.dart';
import '../main/home.dart';
import '../main/my_notes.dart';
import '../main/search.dart';
import '../main/add.dart';
import 'package:nexnote/side/profile.dart';

// Constants for reuse
const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class BottomBar extends StatefulWidget {
  const BottomBar({super.key});

  @override
  State<BottomBar> createState() => _BottomBarState();
}

class _BottomBarState extends State<BottomBar> {
  int _currentIndex = 0;

  static final List<Widget> _pages = <Widget>[
    HomePage(),
    SearchPage(),
    AddNotePage(),
    Center(child: Text('Tools', style: TextStyle(color: Colors.white, fontSize: 24))),
    NotesPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  // Check if current page should show drawer
  bool get _shouldShowDrawer => _currentIndex != 2; // Hide drawer on Add page (index 2)

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions without keyboard insets
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    
    return MediaQuery.removePadding(
      context: context,
      removeBottom: true,
      child: MediaQuery(
        data: mediaQuery.copyWith(
          viewInsets: EdgeInsets.zero,
          viewPadding: mediaQuery.viewPadding.copyWith(bottom: 0),
        ),
        child: Scaffold(
          backgroundColor: kDarkSurface,
          drawerScrimColor: Colors.transparent,
          extendBodyBehindAppBar: false,
          resizeToAvoidBottomInset: false,

          appBar: AppBar(
            title: Text(_getPageTitle()),
            backgroundColor: kDarkSurface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            titleTextStyle: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
            iconTheme: const IconThemeData(color: Colors.white),
            // Conditionally show back button instead of hamburger menu
            leading: _shouldShowDrawer 
                ? null // Show default hamburger menu
                : IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => _onTabTapped(0), // Go back to home
                  ),
            automaticallyImplyLeading: _shouldShowDrawer, // Only show hamburger if drawer is enabled
            // Hide profile picture on Add page
            actions: _shouldShowDrawer ? [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ProfilePage()),
                    );
                  },
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: const Text(
                      "PFP",
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ] : null,
          ),

          // Only show drawer when not on Add page
          drawer: _shouldShowDrawer ? SideBar(onNavigate: _onTabTapped) : null,
          drawerEnableOpenDragGesture: _shouldShowDrawer, // Disable swipe gesture on Add page

          body: Stack(
            children: [
              // Main content with bottom padding
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(bottom: _shouldShowDrawer ? 36 : 0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return SlideTransition(
                        position: animation.drive(
                          Tween(begin: const Offset(0.1, 0), end: Offset.zero)
                              .chain(CurveTween(curve: Curves.easeOut)),
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      key: ValueKey<int>(_currentIndex),
                      color: kDarkSurface,
                      child: _pages[_currentIndex],
                    ),
                  ),
                ),
              ),
              
              // Fixed Bottom Navigation Bar with absolute positioning - Hide on Add page
              if (_shouldShowDrawer) ...[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 72,
                  child: IgnorePointer(
                    ignoring: false,
                    child: Container(
                      color: kDarkSurface,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          height: 60,
                          color: kDarkSurface,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _buildTabItem(icon: Icons.home, index: 0, label: 'Home'),
                              _buildTabItem(icon: Icons.search, index: 1, label: 'Search'),
                              _buildCenterLabel(index: 2, label: 'Add'),
                              _buildTabItem(icon: Icons.build, index: 3, label: 'Tools'),
                              _buildTabItem(icon: Icons.note, index: 4, label: 'Notes'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // Fixed Floating Action Button with absolute positioning
                Positioned(
                  left: screenWidth / 2 - 28,
                  bottom: 48,
                  child: IgnorePointer(
                    ignoring: false,
                    child: FloatingActionButton(
                      backgroundColor: kPrimaryColor,
                      onPressed: () => _onTabTapped(2),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 2:
        return 'Add Note';
      case 4:
        return 'My Notes';
      default:
        return '';
    }
  }

  Widget _buildTabItem({
    required IconData icon,
    required int index,
    required String label,
  }) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.2 : 1.0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                icon,
                color: isSelected ? kPrimaryColor : Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? kPrimaryColor : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterLabel({required int index, required String label}) {
    final bool isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => _onTabTapped(index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 28),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? kPrimaryColor : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}