import 'package:flutter/material.dart';

// Constants for reuse
const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<int> _characterCount;
  final String _fullText = "Welcome Your Name!";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 1750),
      vsync: this,
    );

    _characterCount = StepTween(
      begin: 0,
      end: _fullText.length,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<TextSpan> _buildAnimatedTextSpans(String animatedText) {
  List<TextSpan> spans = [];

  const welcomePrefix = "Welcome ";
  const nameText = "Your Name!";

  if (animatedText.isEmpty) return spans;

  // Add 'Welcome '
  if (animatedText.length <= welcomePrefix.length) {
    spans.add(TextSpan(
      text: animatedText,
      style: TextStyle(color: Colors.white),
    ));
    return spans;
  } else {
    spans.add(TextSpan(
      text: welcomePrefix,
      style: TextStyle(color: Colors.white),
    ));
  }

  // Add 'Your Name'
  final nameStart = welcomePrefix.length;
  final nameEnd = nameStart + nameText.length;

  if (animatedText.length <= nameEnd) {
    spans.add(TextSpan(
      text: animatedText.substring(nameStart),
      style: TextStyle(color: kPrimaryColor),
    ));
    return spans;
  } else {
    spans.add(TextSpan(
      text: nameText,
      style: TextStyle(color: kPrimaryColor),
    ));
  }

  return spans;
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _characterCount,
              builder: (context, child) {
                final animatedText =
                    _fullText.substring(0, _characterCount.value);
                return RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                    children: _buildAnimatedTextSpans(animatedText),
                  ),
                );
              },
            ),
            SizedBox(height: 8),
            Text(
              'What would you like to do with\nyour notes today?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kPrimaryColor,
                fontSize: 16,
                height: 1.4,
              ),
            ),
            SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: ActionButton(
                    icon: Icons.auto_fix_high,
                    label: 'Enhance',
                    backgroundColor: kCardColor,
                    textColor: kAccentYellow,
                    borderColor: kAccentYellow,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ActionButton(
                    icon: Icons.compare_arrows,
                    label: 'Compare',
                    backgroundColor: kPrimaryColor,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Center(
              child: SizedBox(
                width: 150,
                child: ActionButton(
                  icon: Icons.merge_type,
                  label: 'Combine',
                  backgroundColor: kCardColor,
                  textColor: kPrimaryColor,
                  borderColor: kPrimaryColor,
                ),
              ),
            ),
            SizedBox(height: 32),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: kAccentYellow, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Explore public lecture notes',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: SearchFilterSortBox(icon: Icons.search, label: 'Search'),
                ),
                SizedBox(width: 12),
                SearchFilterSortBox(icon: Icons.filter_alt, label: 'Filter'),
                SizedBox(width: 12),
                SearchFilterSortBox(icon: Icons.sort, label: 'Sort'),
              ],
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Community Notes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'View All >',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.2,
              children: [
                NoteCard(title: 'Statistics', backgroundColor: Colors.white, hasColoredElements: true),
                NoteCard(title: 'Matematika', backgroundColor: Color(0xFFFFF3CD), hasColoredElements: true),
                NoteCard(title: 'Cara Dapat Pacar', backgroundColor: Colors.white, hasColoredElements: false),
                NoteCard(title: 'Biografi Darrell', backgroundColor: Color(0xFFFFE5E5), hasColoredElements: true),
                NoteCard(title: 'Physics', backgroundColor: Color(0xFFFFF0F0), hasColoredElements: true),
                NoteCard(title: 'Biology', backgroundColor: Color(0xFFFFF8E1), hasColoredElements: true),
              ],
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;

  const ActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: borderColor != null
            ? Border.all(color: borderColor!, width: 1.5)
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 20),
          SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class NoteCard extends StatelessWidget {
  final String title;
  final Color backgroundColor;
  final bool hasColoredElements;

  const NoteCard({super.key, 
    required this.title,
    required this.backgroundColor,
    required this.hasColoredElements,
  });

  @override
  Widget build(BuildContext context) {
    Widget coloredLine(Color? color, double widthFactor) {
      return FractionallySizedBox(
        widthFactor: widthFactor,
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: color ?? Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 20,
                  decoration: BoxDecoration(
                    color: hasColoredElements ? Colors.blue[100] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                SizedBox(height: 8),
                coloredLine(Colors.grey[300], 1.0),
                SizedBox(height: 4),
                coloredLine(Colors.grey[300], 0.8),
                SizedBox(height: 4),
                if (hasColoredElements)
                  ...[
                    coloredLine(Colors.orange[200], 0.6),
                    SizedBox(height: 4),
                  ],
                coloredLine(Colors.grey[300], 0.9),
              ],
            ),
          ),
          SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              color: Colors.black87,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class SearchFilterSortBox extends StatelessWidget {
  final IconData icon;
  final String label;

  const SearchFilterSortBox({super.key, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.grey[600], size: 20),
          SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}


