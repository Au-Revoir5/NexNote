import 'package:flutter/material.dart';
import 'side_bar.dart';
import '../main/home.dart';
import '../main/notes.dart';
import '../main/search.dart';

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
    Center(child: Text('Add', style: TextStyle(color: Colors.white, fontSize: 24))),
    Center(child: Text('Tools', style: TextStyle(color: Colors.white, fontSize: 24))),
    NotesPage(),
  ];

  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ✅ Prevent background flicker by explicitly setting same color everywhere
      backgroundColor: kDarkSurface,
      drawerScrimColor: Colors.transparent,
      extendBodyBehindAppBar: false,

      appBar: AppBar(
        title: Text(_getPageTitle()),
        backgroundColor: kDarkSurface,
        elevation: 0,
        // ✅ Prevent dynamic tinting flicker (especially Android 12+)
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
                Scaffold.of(context).openDrawer();
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

      drawer: SideBar(onNavigate: _onTabTapped),

      body: AnimatedSwitcher(
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
          color: kDarkSurface, // ✅ Keep background stable here too
          child: _pages[_currentIndex],
        ),
      ),

      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: FloatingActionButton(
          backgroundColor: kPrimaryColor,
          onPressed: () => _onTabTapped(2),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: Padding(
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
    );
  }

  String _getPageTitle() {
    switch (_currentIndex) {
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
