import 'package:flutter/material.dart';

import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/app_theme.dart';
import '../../core/router/app_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _currentPage = 0;

  static const _slides = [
    _SlideData(
      icon: Icons.favorite_rounded,
      isIcon: false,
      color: AppColors.primary,
      title: 'Your Emotional\nCompanion',
      subtitle:
          'Emori is your safe space to express how you feel. Talk, type, or share images — we listen without judgement and help you make sense of your emotions.',
      features: [
        '💬  Express freely in your own words',
        '🔒  Private & encrypted journaling',
        '🤗  Zero judgement, always supportive',
      ],
    ),
    _SlideData(
      icon: Icons.psychology_rounded,
      isIcon: true,
      color: AppColors.coral,
      title: 'Your AI\nSecond Brain',
      subtitle:
          'Every thought you share becomes a searchable memory. Ask Emori anything about your past entries — it remembers so you don\'t have to.',
      features: [
        '🧠  AI-powered memory & recall',
        '🔍  Search across all your entries',
        '✨  Auto-organizes emotions & themes',
      ],
    ),
    _SlideData(
      icon: Icons.insights_rounded,
      isIcon: true,
      color: AppColors.teal,
      title: 'Discover Your\nPatterns',
      subtitle:
          'See how your emotions evolve over time. Get weekly reflections, spot recurring patterns, and grow with personalized insights.',
      features: [
        '📊  Visual emotion tracking',
        '📝  Weekly AI reflections',
        '🎯  Spot patterns & grow',
      ],
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('hasSeenOnboarding', true);

    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppRouter(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isLastPage = _currentPage == _slides.length - 1;

    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Skip button ──────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 16, right: 20),
                child: TextButton(
                  onPressed: _completeOnboarding,
                  child: Text(
                    'Skip',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: c.textHint,
                    ),
                  ),
                ),
              ),
            ),

            // ─── Page View ────────────────────────────────
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (context, index) {
                  final slide = _slides[index];
                  return _SlideView(slide: slide, colors: c);
                },
              ),
            ),

            // ─── Indicator + Button ───────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 48),
              child: Column(
                children: [
                  SmoothPageIndicator(
                    controller: _controller,
                    count: _slides.length,
                    effect: ExpandingDotsEffect(
                      dotHeight: 8,
                      dotWidth: 8,
                      expansionFactor: 3,
                      spacing: 6,
                      activeDotColor: AppColors.primary,
                      dotColor: c.border,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // ─── Action button ────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (isLastPage) {
                          _completeOnboarding();
                        } else {
                          _controller.nextPage(
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeInOut,
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.teal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isLastPage ? 'Get Started' : 'Next',
                        style: TextStyle(
                          fontFamily: 'PlusJakartaSans',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
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

// ─── Slide Data ─────────────────────────────────────────────────

class _SlideData {
  final IconData icon;
  final bool isIcon;
  final Color color;
  final String title;
  final String subtitle;
  final List<String> features;

  const _SlideData({
    required this.icon,
    this.isIcon = true,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.features,
  });
}

// ─── Slide View ─────────────────────────────────────────────────

class _SlideView extends StatelessWidget {
  final _SlideData slide;
  final EmoriColors colors;

  const _SlideView({required this.slide, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ─── Icon circle ─────────────────────────────
          Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      slide.color.withValues(alpha: 0.15),
                      slide.color.withValues(alpha: 0.05),
                    ],
                  ),
                  border: Border.all(
                    color: slide.color.withValues(alpha: 0.2),
                    width: 1.5,
                  ),
                ),
                child: slide.isIcon
                    ? Icon(slide.icon, size: 52, color: slide.color)
                    : Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: SvgPicture.asset(
                          'assets/icons/emori_icon2.svg',
                          colorFilter: ColorFilter.mode(
                            slide.color,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
              )
              .animate()
              .fadeIn(duration: 500.ms)
              .scale(
                begin: const Offset(0.8, 0.8),
                end: const Offset(1, 1),
                duration: 600.ms,
                curve: Curves.easeOutBack,
              ),

          const SizedBox(height: 48),

          // ─── Title ───────────────────────────────────
          Text(
                slide.title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'PlusJakartaSans',
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 500.ms)
              .slideY(begin: 0.2, end: 0, duration: 500.ms),

          const SizedBox(height: 20),

          // ─── Subtitle ────────────────────────────────
          Text(
                slide.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: colors.textSecondary,
                  height: 1.55,
                ),
              )
              .animate()
              .fadeIn(delay: 400.ms, duration: 500.ms)
              .slideY(begin: 0.15, end: 0, duration: 500.ms),

          const SizedBox(height: 28),

          // ─── Feature bullets ─────────────────────────
          ...slide.features.asMap().entries.map((entry) {
            final i = entry.key;
            final feature = entry.value;
            return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: colors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                )
                .animate()
                .fadeIn(delay: (500 + i * 100).ms, duration: 400.ms)
                .slideX(begin: -0.1, end: 0, duration: 400.ms);
          }),
        ],
      ),
    );
  }
}
