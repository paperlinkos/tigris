import 'package:flutter/material.dart';
import '../app/theme/app_typography.dart';
import '../app/theme/context_theme_extensions.dart';
import '../widgets/brand/tigris_logo.dart';
import 'login_screen.dart';

class OnboardingSlide {
  final IconData icon;
  final String category;
  final String title;
  final String description;

  const OnboardingSlide({
    required this.icon,
    required this.category,
    required this.title,
    required this.description,
  });
}

class OnboardingScreen extends StatefulWidget {
  final VoidCallback? onComplete;

  const OnboardingScreen({super.key, this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  static const List<OnboardingSlide> _slides = [
    OnboardingSlide(
      icon: Icons.flash_on_rounded,
      category: 'INSTANT CAPTURE',
      title: 'Offline-First & Lightning Fast',
      description: 'Your notes save instantly on device with 0ms latency. No internet required to capture your best thoughts.',
    ),
    OnboardingSlide(
      icon: Icons.account_tree_rounded,
      category: 'DEEP ORGANISATION',
      title: 'Nested Streams & Subpages',
      description: 'Deconstruct complex topics into infinite subpages and streams without losing context.',
    ),
    OnboardingSlide(
      icon: Icons.psychology_rounded,
      category: 'ACTIVE RECALL',
      title: 'AI Flashcards & Spaced Review',
      description: 'Turn your notes into flashcards, quizzes, and reflection dialogues designed for long-term retention.',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToLogin() {
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: context.appBg,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Logo & Skip
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const TigrisLogo(size: 28.0, showWordmark: true),
                  if (!isLastPage)
                    TextButton(
                      onPressed: _navigateToLogin,
                      child: Text(
                        'Skip',
                        style: AppTypography.uiLabel(
                          fontSize: 14.0,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // PageView Carousel
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (idx) {
                  setState(() => _currentPage = idx);
                },
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 84.0,
                          height: 84.0,
                          decoration: BoxDecoration(
                            color: context.appSurface,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.appBorderSubtle, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(context.isDarkMode ? 40 : 15),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            slide.icon,
                            size: 38.0,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 36.0),
                        Text(
                          slide.category,
                          style: AppTypography.uiLabel(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.appTextSecondary,
                          ).copyWith(letterSpacing: 1.4),
                        ),
                        const SizedBox(height: 12.0),
                        Text(
                          slide.title,
                          textAlign: TextAlign.center,
                          style: AppTypography.display(
                            fontSize: 26.0,
                            color: context.appTextPrimary,
                          ),
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          slide.description,
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            fontSize: 15.5,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Bottom Navigation Row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
              child: Column(
                children: [
                  // Indicators
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _slides.length,
                      (idx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4.0),
                        width: _currentPage == idx ? 24.0 : 8.0,
                        height: 8.0,
                        decoration: BoxDecoration(
                          color: _currentPage == idx ? context.appTextPrimary : context.appBorderSubtle,
                          borderRadius: BorderRadius.circular(4.0),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28.0),

                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52.0,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _navigateToLogin();
                        } else {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: context.appTextPrimary,
                        foregroundColor: context.appBg,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.0),
                        ),
                      ),
                      child: Text(
                        isLastPage ? 'Get Started' : 'Next',
                        style: AppTypography.uiHeadline(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w600,
                          color: context.appBg,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
