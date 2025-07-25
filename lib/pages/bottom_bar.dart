import 'package:flutter/material.dart';
import 'home.dart';
import 'notes.dart';
import 'search.dart';

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
    Center(child: Text('Add')),
    Center(child: Text('Tools')),
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
      body: _pages[_currentIndex],

      floatingActionButton: FloatingActionButton(
        backgroundColor: kPrimaryColor,
        onPressed: () => _onTabTapped(2),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(bottom: 12), // add bottom margin
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
