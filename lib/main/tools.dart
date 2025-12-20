import 'package:flutter/material.dart';


class EnhanceCompareCombinePage extends StatefulWidget {
  const EnhanceCompareCombinePage({super.key});

  @override
  State<EnhanceCompareCombinePage> createState() =>
      _EnhanceCompareCombinePageState();
}

class _EnhanceCompareCombinePageState
    extends State<EnhanceCompareCombinePage> {
  int selectedTab = 1; // 0 = Enhance, 1 = Compare, 2 = Combine

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F14),
      body: Stack(
        children: [
          // MAIN CONTENT
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTabs(),
                const SizedBox(height: 24),
                _buildCompareCard(),
              ],
            ),
          ),

          // UNDER CONSTRUCTION OVERLAY
          _buildUnderConstructionOverlay(),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Row(
      children: [
        _tabButton("Enhance", 0),
        const SizedBox(width: 12),
        _tabButton("Compare", 1),
        const SizedBox(width: 12),
        _tabButton("Combine", 2),
      ],
    );
  }

  Widget _tabButton(String title, int index) {
    final bool active = selectedTab == index;

    return GestureDetector(
      onTap: () {
        setState(() => selectedTab = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: active ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? Colors.deepPurple : Colors.grey.shade700,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: active ? Colors.white : Colors.grey,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildCompareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF181820),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Compare Notes",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Select two or more notes to compare side by side",
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF101018),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700),
            ),
            child: const Center(
              child: Icon(
                Icons.add,
                size: 40,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: null, // disabled (under construction)
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade700,
              disabledBackgroundColor: Colors.grey.shade700,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text("Compare"),
          ),
        ],
      ),
    );
  }

  Widget _buildUnderConstructionOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(
              Icons.construction,
              size: 72,
              color: Color(0xFF6366F1),
            ),
            SizedBox(height: 16),
            Text(
              "Under Construction",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              "This feature is currently being built",
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
