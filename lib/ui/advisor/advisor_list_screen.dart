import 'package:flutter/material.dart';
import '../../data/advisors.dart';
import '../../theme/app_theme.dart';
import 'advisor_profile_screen.dart';

/// The roster of curated travel advisors.
///
/// Deliberately a list, not a grid of cards: the decision here is a comparison
/// across a handful of people on the same few axes — where they know, how well
/// they're rated, what they charge — and rows put those axes in columns the eye
/// can run straight down.
class AdvisorListScreen extends StatelessWidget {
  const AdvisorListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Advisors', style: AppText.display(20)),
      ),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          itemCount: kAdvisors.length + 1,
          separatorBuilder: (context, i) => i == 0
              ? const SizedBox(height: 6)
              : Divider(height: 1, thickness: 1, color: AppColors.hairline),
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Text(
                  'People who know one place deeply, or many places well. '
                  'Pick one and they will build your plan around it.',
                  style: AppText.body(14, color: AppColors.textSecondary),
                ),
              );
            }
            final advisor = kAdvisors[i - 1];
            return _AdvisorRow(
              advisor: advisor,
              index: i - 1,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdvisorProfileScreen(advisor: advisor),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdvisorRow extends StatelessWidget {
  final Advisor advisor;
  final int index;
  final VoidCallback onTap;
  const _AdvisorRow({required this.advisor, required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 320 + 60 * index.clamp(0, 5)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 14), child: child),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Monogram(initials: advisor.initials),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(advisor.name, style: AppText.body(16, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          advisor.isAllAround
                              ? Icons.public_rounded
                              : Icons.place_rounded,
                          size: 12,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            advisor.expertiseLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.label(11, color: AppColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    _RatingLine(rating: advisor.rating, reviews: advisor.reviews),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PriceTag(advisor: advisor),
            ],
          ),
        ),
      ),
    );
  }
}

/// Initials on a tinted field. No stock headshots — inventing faces for people
/// who don't exist yet would be the one dishonest thing on this screen.
class _Monogram extends StatelessWidget {
  final String initials;
  const _Monogram({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.accent.withValues(alpha: 0.22),
            AppColors.accentAlt.withValues(alpha: 0.10),
          ],
        ),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.28)),
      ),
      child: Text(initials, style: AppText.display(17, color: AppColors.accent)),
    );
  }
}

class _RatingLine extends StatelessWidget {
  final double rating;
  final int reviews;
  const _RatingLine({required this.rating, required this.reviews});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.star_rounded, size: 13, color: AppColors.accent),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: AppText.label(11, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 5),
        Text('($reviews)', style: AppText.label(11, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Price, or a Free chip. Right-aligned so the column scans as one.
class _PriceTag extends StatelessWidget {
  final Advisor advisor;
  const _PriceTag({required this.advisor});

  @override
  Widget build(BuildContext context) {
    if (advisor.isFree) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Text('FREE', style: AppText.label(10, color: AppColors.accent)),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text('\$${advisor.pricePerPlan}', style: AppText.display(20)),
        const SizedBox(height: 2),
        Text('PER PLAN', style: AppText.label(8, color: AppColors.textMuted)),
      ],
    );
  }
}
