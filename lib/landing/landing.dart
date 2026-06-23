import 'package:flutter/material.dart';
import 'login.dart';
import 'signup.dart';

const kPrimaryColor = Color(0xFF6366F1);
const kDarkSurface = Color(0xFF1C1C1E);
const kCardColor = Color(0xFF2C2C2E);
const kAccentYellow = Color(0xFFFBBF24);

class LandingPage extends StatefulWidget {
  const LandingPage({super.key});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<OnboardingContent> _pages = [
    OnboardingContent(
      title: 'PDFs and Docs, all in one place.',
      highlightedWord: 'PDF & DOCX',
      description: ' files stored privately\nor shared with the world.',
    ),
    OnboardingContent(
      title: 'Organize your thoughts seamlessly.',
      highlightedWord: 'Capture',
      description: ' ideas and notes with\npowerful organization tools.',
    ),
    OnboardingContent(
      title: 'Discover notes from the community.',
      highlightedWord: 'Download',
      description: ' public notes shared\nby other students instantly.',
    ),
  ];

  List<Widget> get _illustrations => const [
    _FilesIllustration(),
    _CaptureIllustration(),
    _CommunityIllustration(),
  ];

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final horizontalPadding = screenWidth * 0.08;
    final cardMargin = screenWidth * 0.06;
    final cardPadding = screenWidth * 0.05;
    final titleFontSize = screenWidth * 0.09;
    final descriptionFontSize = screenWidth * 0.038;

    return Scaffold(
      backgroundColor: kDarkSurface,
      body: SafeArea(
        child: Column(
          children: [
            // Welcome text
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding.clamp(24.0, 40.0),
                screenHeight * 0.03,
                horizontalPadding.clamp(24.0, 40.0),
                screenHeight * 0.01,
              ),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: titleFontSize.clamp(26.0, 36.0),
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      children: const [
                        TextSpan(text: 'Welcome to '),
                        TextSpan(
                          text: 'NexNote',
                          style: TextStyle(color: kPrimaryColor),
                        ),
                        TextSpan(text: '!'),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.008),
                  Text(
                    'Please log in or create an account to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: descriptionFontSize.clamp(11.0, 13.0),
                      color: Colors.grey[500],
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            // Carousel card
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: cardMargin.clamp(20.0, 28.0),
                  vertical: screenHeight * 0.012,
                ),
                padding: EdgeInsets.all(cardPadding.clamp(16.0, 24.0)),
                decoration: BoxDecoration(
                  color: kCardColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() => _currentPage = index);
                        },
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _illustrations[index],
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: descriptionFontSize.clamp(12.0, 15.0),
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: '${_pages[index].title}\n',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _pages[index].highlightedWord,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: kPrimaryColor,
                                          ),
                                        ),
                                        TextSpan(
                                          text: _pages[index].description,
                                          style: TextStyle(color: Colors.grey[400]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Pagination dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          width: _currentPage == index
                              ? (screenWidth * 0.05).clamp(18.0, 24.0)
                              : (screenWidth * 0.02).clamp(6.0, 8.0),
                          height: (screenWidth * 0.02).clamp(6.0, 8.0),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? kPrimaryColor
                                : Colors.grey[600],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 4),

                    // Next button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _nextPage,
                        icon: Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: descriptionFontSize.clamp(12.0, 14.0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        label: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Login / Sign Up buttons
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding.clamp(24.0, 40.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenHeight * 0.015),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimaryColor,
                      padding: EdgeInsets.symmetric(
                        vertical: (screenHeight * 0.018).clamp(12.0, 16.0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Login',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.042).clamp(14.0, 16.0),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.012),

                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[700]!, width: 1.5),
                      padding: EdgeInsets.symmetric(
                        vertical: (screenHeight * 0.018).clamp(12.0, 16.0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: kCardColor,
                    ),
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.042).clamp(14.0, 16.0),
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.015),

                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: (screenWidth * 0.034).clamp(10.0, 12.0),
                        height: 1.4,
                      ),
                      children: const [
                        TextSpan(text: 'Need help? Visit our '),
                        TextSpan(
                          text: 'Help Center',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        TextSpan(text: ' or contact support.'),
                      ],
                    ),
                  ),

                  SizedBox(height: screenHeight * 0.02),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------
// Data model
// -------------------------------------------------------------
class OnboardingContent {
  final String title;
  final String highlightedWord;
  final String description;

  const OnboardingContent({
    required this.title,
    required this.highlightedWord,
    required this.description,
  });
}

// -------------------------------------------------------------
// Shared helpers
// -------------------------------------------------------------
List<Widget> _fakeLines(List<double> widths, Color color, {double height = 7}) {
  return widths
      .map((w) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: FractionallySizedBox(
              widthFactor: w,
              alignment: Alignment.centerLeft,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ))
      .toList();
}

Widget _pill(String label, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: fg,
        fontSize: 10,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

// -------------------------------------------------------------
// Illustration 1 — PDF & DOCX Files
// -------------------------------------------------------------
class _FilesIllustration extends StatelessWidget {
  const _FilesIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cardW = (w * 0.42).clamp(0.0, 160.0);

        return SizedBox(
          width: w,
          height: h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // PDF card
              SizedBox(
                width: cardW,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.redAccent.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PDF',
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.picture_as_pdf,
                            color: Colors.redAccent,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 9,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._fakeLines(
                        [0.9, 0.75, 0.85, 0.6],
                        Colors.grey[600]!,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.lock_outline,
                              color: kAccentYellow, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            'Private',
                            style: TextStyle(
                              color: kAccentYellow,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: kPrimaryColor.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: kPrimaryColor.withOpacity(0.4),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.add,
                        color: kPrimaryColor,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),

              // DOCX card
              SizedBox(
                width: cardW,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF3A3A3E),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.blueAccent.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'DOCX',
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.description_outlined,
                            color: Colors.blueAccent,
                            size: 16,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 9,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._fakeLines(
                        [0.85, 0.65, 0.9, 0.7],
                        Colors.grey[600]!,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.public,
                              color: Colors.greenAccent, size: 12),
                          const SizedBox(width: 4),
                          const Text(
                            'Public',
                            style: TextStyle(
                              color: Colors.greenAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// Illustration 2 — Capture
// -------------------------------------------------------------
class _CaptureIllustration extends StatelessWidget {
  const _CaptureIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              // Back card
              Positioned(
                top: h * 0.1,
                left: w * 0.08,
                right: 0,
                child: Container(
                  height: h * 0.7,
                  decoration: BoxDecoration(
                    color: const Color(0xFF363638),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // Mid card
              Positioned(
                top: h * 0.05,
                left: w * 0.04,
                right: w * 0.04,
                child: Container(
                  height: h * 0.7,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E3E40),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              // Front card
              Positioned(
                top: 0,
                left: 0,
                right: w * 0.08,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF48484A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: kPrimaryColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.edit_note,
                              color: kPrimaryColor, size: 16),
                          const SizedBox(width: 8),
                          Container(
                            height: 9,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._fakeLines(
                        [0.9, 0.7, 0.8],
                        Colors.grey[600]!,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [
                          _pill('Lecture',
                              kPrimaryColor.withOpacity(0.2), kPrimaryColor),
                          _pill('Week 3',
                              kAccentYellow.withOpacity(0.15), kAccentYellow),
                          _pill('CS101',
                              Colors.teal.withOpacity(0.15), Colors.teal[300]!),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------
// Illustration 3 — Community Notes
// -------------------------------------------------------------
class _CommunityIllustration extends StatelessWidget {
  const _CommunityIllustration();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;

        return SizedBox(
          width: w,
          height: h,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _communityNoteCard(
                name: 'sarah_k',
                title: 'Calculus Notes — Week 5',
                fileType: 'PDF',
                fileColor: Colors.redAccent,
                avatarColor: kPrimaryColor,
                initials: 'SK',
                lineWidths: [0.9, 0.7, 0.8],
              ),
              SizedBox(height: h * 0.04),
              _communityNoteCard(
                name: 'alex_m',
                title: 'Data Structures Summary',
                fileType: 'DOCX',
                fileColor: Colors.blueAccent,
                avatarColor: Colors.teal,
                initials: 'AM',
                lineWidths: [0.85, 0.65, 0.75],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _communityNoteCard({
    required String name,
    required String title,
    required String fileType,
    required Color fileColor,
    required Color avatarColor,
    required String initials,
    required List<double> lineWidths,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3A3A3E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: avatarColor.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: avatarColor.withOpacity(0.4), width: 1),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: avatarColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: fileColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fileType,
                        style: TextStyle(
                          color: fileColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                ..._fakeLines(lineWidths, Colors.grey[700]!, height: 6),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Download button
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(
                color: kPrimaryColor.withOpacity(0.4),
                width: 1,
              ),
            ),
            child: const Icon(
              Icons.download_outlined,
              color: kPrimaryColor,
              size: 16,
            ),
          ),
        ],
      ),
    );
  }
}