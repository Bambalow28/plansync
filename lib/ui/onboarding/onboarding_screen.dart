import 'package:flutter/material.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_theme.dart';

class _Slide {
  final Widget Function() mockup;
  final String title;
  final String description;
  const _Slide(this.mockup, this.title, this.description);
}

final _slides = [
  _Slide(
    () => const _HomeMockup(),
    'Plan every trip in one place',
    'Keep destinations, dates, and budgets together for each trip.',
  ),
  _Slide(
    () => const _ItineraryMockup(),
    'Day-by-day itineraries',
    'Lay out flights, stays, and activities on a simple daily timeline.',
  ),
  _Slide(
    () => const _BudgetMockup(),
    'Track your budget as you go',
    'See spending against your budget without leaving the app.',
  ),
  _Slide(
    () => const _NotificationMockup(),
    'Never miss what\'s next',
    'Get reminders and a Lock Screen live activity for your next plan.',
  ),
];

/// First-launch walkthrough of PlanSync's core features.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  Future<void> _finish() async {
    await OnboardingService.instance.setOnboardingSeen();
    if (mounted) Navigator.of(context).pop();
  }

  void _next() {
    if (_page == _slides.length - 1) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Opacity(
                  opacity: isLast ? 0 : 1,
                  child: TextButton(
                    onPressed: isLast ? null : _finish,
                    child: Text(
                      'Skip',
                      style: AppText.body(14, color: AppColors.textSecondary),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [for (final s in _slides) _SlideView(slide: s)],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: i == _page ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: i == _page
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
              child: GestureDetector(
                onTap: _next,
                child: Container(
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    isLast ? 'GET STARTED' : 'CONTINUE',
                    style: AppText.body(
                      16,
                      color: Colors.black,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  final _Slide slide;
  const _SlideView({required this.slide});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          slide.mockup(),
          const SizedBox(height: 32),
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: AppText.display(24),
          ),
          const SizedBox(height: 12),
          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: AppText.body(15, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Shared device-like frame every mini mockup sits inside.
class _MockupFrame extends StatelessWidget {
  final Widget child;
  const _MockupFrame({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.hairline),
      ),
      child: child,
    );
  }
}

Widget _bar(double width, double height, Color color, {double opacity = 1}) {
  return Container(
    width: width,
    height: height,
    decoration: BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(height / 2),
    ),
  );
}

/// Mini "Your trips" home screen — two trip cards with a title, date bar,
/// and budget progress.
class _HomeMockup extends StatelessWidget {
  const _HomeMockup();

  @override
  Widget build(BuildContext context) {
    Widget tripRow(List<Color> colors, double budgetRatio) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _bar(70, 8, Colors.black, opacity: 0.55),
                const Spacer(),
                _bar(20, 16, Colors.black, opacity: 0.2),
              ],
            ),
            const SizedBox(height: 6),
            _bar(50, 5, Colors.black, opacity: 0.3),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: budgetRatio,
                minHeight: 4,
                backgroundColor: Colors.black.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.black87),
              ),
            ),
          ],
        ),
      );
    }

    return _MockupFrame(
      child: Column(
        children: [
          tripRow([AppColors.accent, AppColors.accentAlt], 0.65),
          const SizedBox(height: 10),
          tripRow(const [Color(0xFF8B7BD8), Color(0xFFB58AE0)], 0.3),
        ],
      ),
    );
  }
}

/// Mini day timeline — dots joined by a dashed rail, one per plan.
class _ItineraryMockup extends StatelessWidget {
  const _ItineraryMockup();

  @override
  Widget build(BuildContext context) {
    Widget row(double titleWidth, {bool isLast = false}) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.background,
                    border: Border.all(color: AppColors.accent, width: 2),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: AppColors.accent.withValues(alpha: 0.35),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(titleWidth, 7, AppColors.textPrimary, opacity: 0.85),
                  const SizedBox(height: 6),
                  _bar(titleWidth * 0.6, 5, AppColors.textMuted),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _MockupFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row(90),
          row(70),
          row(100, isLast: true),
        ],
      ),
    );
  }
}

/// Mini budget readout — big percentage, progress bar, spent/left labels.
class _BudgetMockup extends StatelessWidget {
  const _BudgetMockup();

  @override
  Widget build(BuildContext context) {
    return _MockupFrame(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('83%', style: AppText.display(30, color: AppColors.accent)),
          const SizedBox(height: 2),
          Text('of budget used', style: AppText.label(10, color: AppColors.textMuted)),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: 0.83,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.3),
              valueColor: const AlwaysStoppedAnimation(AppColors.accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('\$2,490 spent', style: AppText.label(11, color: AppColors.textSecondary)),
              Text('\$510 left', style: AppText.label(11, color: AppColors.accent)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Mini Lock Screen live activity — icon, headline, and countdown.
class _NotificationMockup extends StatelessWidget {
  const _NotificationMockup();

  @override
  Widget build(BuildContext context) {
    return _MockupFrame(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              gradient: AppColors.accentGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.flight_rounded, size: 18, color: Colors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Flight to Tokyo', style: AppText.body(13, weight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text('Boarding in 2h 15m', style: AppText.label(10, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
