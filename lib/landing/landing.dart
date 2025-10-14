import 'package:flutter/material.dart';
import 'login.dart';
import 'signup.dart';

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
      image: 'assets/landing_illustration.png',
      title: 'Spot the differences in seconds.',
      highlightedWord: 'Compare',
      description: ' two or more notes side by\nside with AI-powered insights.',
    ),
    OnboardingContent(
      image: 'assets/landing_illustration2.png',
      title: 'Organize your thoughts seamlessly.',
      highlightedWord: 'Capture',
      description: ' ideas and notes with\npowerful organization tools.',
    ),
    OnboardingContent(
      image: 'assets/landing_illustration3.png',
      title: 'Sync across all your devices.',
      highlightedWord: 'Access',
      description: ' your notes anytime,\nanywhere with cloud sync.',
    ),
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
    
    // Responsive values based on screen size
    final horizontalPadding = screenWidth * 0.08;
    final cardMargin = screenWidth * 0.06;
    final cardPadding = screenWidth * 0.06;
    final titleFontSize = screenWidth * 0.09;
    final descriptionFontSize = screenWidth * 0.038;

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: SafeArea(
        child: Column(
          children: [
            // Welcome text section at top
            Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding.clamp(24.0, 40.0),
                screenHeight * 0.03,
                horizontalPadding.clamp(24.0, 40.0),
                screenHeight * 0.02,
              ),
              child: Column(
                children: [
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: titleFontSize.clamp(28.0, 38.0),
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                      children: const [
                        TextSpan(text: 'Welcome to '),
                        TextSpan(
                          text: 'NexNote',
                          style: TextStyle(
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                        TextSpan(text: '!'),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.01),
                  Text(
                    'Please log in or create an account to get started.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: descriptionFontSize.clamp(12.0, 14.0),
                      color: const Color(0xFF6B7280),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            // Card container for illustration and text - takes available space
            Expanded(
              flex: 3,
              child: Container(
                margin: EdgeInsets.symmetric(
                  horizontal: cardMargin.clamp(20.0, 28.0),
                  vertical: screenHeight * 0.015,
                ),
                padding: EdgeInsets.all(cardPadding.clamp(20.0, 28.0)),
                decoration: BoxDecoration(
                  color: const Color.fromRGBO(237, 237, 237, 1), 
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Illustration PageView - takes most of the card space
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (index) {
                          setState(() {
                            _currentPage = index;
                          });
                        },
                        itemCount: _pages.length,
                        itemBuilder: (context, index) {
                          return Column(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Image.asset(
                                  _pages[index].image,
                                  fit: BoxFit.contain,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: RichText(
                                    textAlign: TextAlign.center,
                                    text: TextSpan(
                                      style: TextStyle(
                                        fontSize: descriptionFontSize.clamp(13.0, 16.0),
                                        color: Colors.black,
                                        height: 1.5,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: _pages[index].title + '\n',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                        TextSpan(
                                          text: _pages[index].highlightedWord,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF8B5CF6),
                                          ),
                                        ),
                                        TextSpan(
                                          text: _pages[index].description,
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
                    const SizedBox(height: 12),
                    // Pagination dots
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _pages.length,
                        (index) => Container(
                          width: (screenWidth * 0.02).clamp(6.0, 8.0),
                          height: (screenWidth * 0.02).clamp(6.0, 8.0),
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.black
                                : Colors.grey[400],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Next button
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _nextPage,
                        icon: Text(
                          'Next',
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: descriptionFontSize.clamp(13.0, 15.0),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        label: Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.black,
                          size: (screenWidth * 0.04).clamp(14.0, 16.0),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Login and Sign Up buttons at bottom
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding.clamp(24.0, 40.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: screenHeight * 0.02),
                  // Login Button
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      padding: EdgeInsets.symmetric(
                        vertical: (screenHeight * 0.02).clamp(14.0, 18.0),
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
                  SizedBox(height: screenHeight * 0.015),
                  // Sign Up Button
                  OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignUpPage()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 1.5),
                      padding: EdgeInsets.symmetric(
                        vertical: (screenHeight * 0.02).clamp(14.0, 18.0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      backgroundColor: Colors.white,
                    ),
                    child: Text(
                      'Sign Up',
                      style: TextStyle(
                        fontSize: (screenWidth * 0.042).clamp(14.0, 16.0),
                        color: Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.02),
                  // Help text
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        color: const Color(0xFF6B7280),
                        fontSize: (screenWidth * 0.034).clamp(11.0, 13.0),
                        height: 1.4,
                      ),
                      children: const [
                        TextSpan(text: 'Need help? Visit our '),
                        TextSpan(
                          text: 'Help Center',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        TextSpan(text: ' or contact support.'),
                      ],
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingContent {
  final String image;
  final String title;
  final String highlightedWord;
  final String description;

  OnboardingContent({
    required this.image,
    required this.title,
    required this.highlightedWord,
    required this.description,
  });
}