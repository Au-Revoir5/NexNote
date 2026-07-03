import 'package:flutter/material.dart';
import 'side_bar.dart';
import '../main/home.dart';
import '../main/my_notes.dart';
import '../main/search.dart';
import '../main/add.dart';
import '../side/favorites.dart'; 
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
  bool _hideAppBar = false;
  bool _hideBottomBar = false;
  bool _disableDrawer = false;
  // ignore: unused_field
  bool _pendingSearchFocus = false;
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _pages = [
      HomePage(onTabRequest: _onTabTapped),
      SearchPage(
        key: SearchPage.searchKey,
        autoFocus: false,
        onSearchingChanged: (isSearching) {
          setState(() {
            _hideAppBar = isSearching;
            _hideBottomBar = isSearching;
            _disableDrawer = isSearching;
          });
        },
      ),
      const FavoritesPage(showAppBar: false),
      NotesPage(
        onSelectionModeChanged: (isSelecting) {
          setState(() {
            _hideAppBar = isSelecting;
            _hideBottomBar = isSelecting;
          });
        },
      ),
    ];
  }

  void _onTabTapped(int index, {bool autoFocusSearch = false}) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddNotePage()),
      );
      return;
    }

    int pageIndex = index < 2 ? index : index - 1;

    setState(() {
      _currentIndex = pageIndex;
      _pendingSearchFocus = autoFocusSearch;
    });

    if (pageIndex == 1 && autoFocusSearch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        SearchPage.searchKey.currentState?.focusSearch();

        _pendingSearchFocus = false;
      });
    }
  }


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

          drawer: _disableDrawer
              ? null
              : SideBar(onNavigate: (index) {
                  if (index < 2) {
                    _onTabTapped(index);
                  } else if (index == 2) {
                    _onTabTapped(2);
                  } else {
                    _onTabTapped(index + 1);
                  }
                }),

          drawerEnableOpenDragGesture: !_disableDrawer,

          appBar: _hideAppBar
          ? null
          : AppBar(
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
              actions: [
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
              ],
            ),

          body: Stack(
            children: [
              // Main content with bottom padding
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 36),
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
              
              // Fixed Bottom Navigation Bar with absolute positioning
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 72,
                child: IgnorePointer(
                  ignoring: _hideBottomBar,
                  child: AnimatedSlide(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    offset: _hideBottomBar ? const Offset(0, 1) : Offset.zero,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 150),
                      opacity: _hideBottomBar ? 0 : 1,
                      child: Container(
                        color: kDarkSurface,
                        padding: const EdgeInsets.only(bottom: 12),
                        child: SizedBox(
                          height: 60,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: <Widget>[
                              _buildTabItem(icon: Icons.home, index: 0, label: 'Home'),
                              _buildTabItem(icon: Icons.search, index: 1, label: 'Search'),
                              _buildCenterLabel(index: 2, label: 'Add'),
                              _buildTabItem(icon: Icons.star, index: 3, label: 'Favorites'), // ⬅️ changed
                              _buildTabItem(icon: Icons.note, index: 4, label: 'Notes'),
                            ],
                          ),
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
                  ignoring: _hideBottomBar,
                  child: AnimatedScale(
                    scale: _hideBottomBar ? 0 : 1,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: _hideBottomBar ? 0 : 1,
                      duration: const Duration(milliseconds: 120),
                      child: FloatingActionButton(
                        backgroundColor: kPrimaryColor,
                        onPressed: () => _onTabTapped(2),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPageTitle() {
    switch (_currentIndex) {
      case 0:
        return ''; // Home
      case 1:
        return ''; // Search
      case 2:
        return 'My Favorites'; // Favorites
      case 3:
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
    // Map bottom bar index to page index for selection highlight
    // Bottom bar: 0=Home, 1=Search, 2=Add, 3=Favorites, 4=Notes
    // Pages: 0=Home, 1=Search, 2=Favorites, 3=Notes
    int pageIndex;
    if (index < 2) {
      pageIndex = index;
    } else if (index == 2) {
      pageIndex = -1; // Add button, never selected
    } else {
      pageIndex = index - 1;
    }
    
    final bool isSelected = _currentIndex == pageIndex;

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
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}