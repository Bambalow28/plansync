import 'package:flutter/material.dart';
import '../../data/advisors.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../shared/add_trip_sheet.dart';
import '../shared/destination_photo.dart';

/// An advisor's profile: who they are, what they've seen, and one action.
///
/// The page is sequenced as an argument — a photograph of the place they know,
/// then the numbers that back them, then their own words, and finally the
/// evidence: the places they've actually spent time in. The request button is
/// pinned so the answer is always one tap away no matter how far down the
/// reader has gone.
class AdvisorProfileScreen extends StatelessWidget {
  final Advisor advisor;
  const AdvisorProfileScreen({super.key, required this.advisor});

  void _requestPlan(BuildContext context) {
    // No backend to send a request to yet, so the useful thing this can do is
    // start the trip it would have produced, seeded with the advisor's city.
    AddTripSheet.show(context, initialDestination: advisor.city);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              _HeroBar(advisor: advisor),
              SliverToBoxAdapter(child: _Stats(advisor: advisor)),
              SliverToBoxAdapter(child: _Bio(advisor: advisor)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 30, 24, 4),
                  child: Text(
                    'WHERE THEY’VE BEEN',
                    style: AppText.label(11, color: AppColors.textMuted),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 140),
                sliver: SliverList.builder(
                  itemCount: advisor.places.length,
                  itemBuilder: (context, i) => _PlaceEntry(
                    place: advisor.places[i],
                    index: i,
                    isLast: i == advisor.places.length - 1,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _RequestBar(advisor: advisor, onTap: () => _requestPlan(context)),
          ),
        ],
      ),
    );
  }
}

/// Collapsing photo header: the place they know, their name over it.
class _HeroBar extends StatelessWidget {
  final Advisor advisor;
  const _HeroBar({required this.advisor});

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 260,
      pinned: true,
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.white),
      // No FlexibleSpaceBar title: a centred collapsing title would sit at odds
      // with the left-aligned block below it, and shifting the block right to
      // meet it just to clear the back button reads worse than leaving the
      // collapsed bar to the chevron alone.
      flexibleSpace: FlexibleSpaceBar(
        background: DestinationPhoto(
          query: advisor.photoQuery,
          gradient: tripCovers[TripCover.teal]!,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      advisor.isAllAround ? Icons.public_rounded : Icons.place_rounded,
                      size: 13,
                      color: AppColors.accent,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        advisor.expertiseLabel.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(11, color: AppColors.accent),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  advisor.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(32),
                ),
                const SizedBox(height: 6),
                Text(
                  advisor.headline,
                  style: AppText.body(14, color: Colors.white.withValues(alpha: 0.9)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The numbers that back the person up.
class _Stats extends StatelessWidget {
  final Advisor advisor;
  const _Stats({required this.advisor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        children: [
          _Stat(
            value: advisor.rating.toStringAsFixed(1),
            label: '${advisor.reviews} REVIEWS',
            accent: true,
          ),
          const _StatDivider(),
          _Stat(value: '${advisor.tripsPlanned}', label: 'TRIPS PLANNED'),
          const _StatDivider(),
          _Stat(value: '${advisor.yearsExperience}y', label: 'EXPERIENCE'),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;
  const _Stat({required this.value, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: AppText.display(24, color: accent ? AppColors.accent : null),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.label(9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 30, color: AppColors.hairline);
}

class _Bio extends StatelessWidget {
  final Advisor advisor;
  const _Bio({required this.advisor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 26, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            advisor.bio,
            style: AppText.body(15, color: AppColors.textSecondary).copyWith(height: 1.55),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in advisor.languages) _LanguageChip(label: language),
            ],
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  const _LanguageChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Text(label, style: AppText.label(10, color: AppColors.textSecondary)),
    );
  }
}

/// One place they've been: a photo tile on a continuous timeline rail, with
/// the year and their own line about it. The rail is what makes this read as a
/// travelled life rather than a list of tags.
class _PlaceEntry extends StatelessWidget {
  final AdvisorPlace place;
  final int index;
  final bool isLast;
  const _PlaceEntry({required this.place, required this.index, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + 90 * index.clamp(0, 5)),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset((1 - t) * 16, 0), child: child),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The rail: a node per stop, joined by a line that stops at the last.
            Column(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: AppColors.hairline),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(15, weight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${place.year}',
                          style: AppText.label(11, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: SizedBox(
                        height: 108,
                        width: double.infinity,
                        child: DestinationPhoto(
                          query: place.photoQuery,
                          gradient: tripCovers[TripCover.values[index % TripCover.values.length]]!,
                          child: const SizedBox.shrink(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      place.note,
                      style: AppText.body(13, color: AppColors.textSecondary).copyWith(height: 1.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pinned action. Names the price up front so the tap holds no surprise.
class _RequestBar extends StatelessWidget {
  final Advisor advisor;
  final VoidCallback onTap;
  const _RequestBar({required this.advisor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: AppColors.accentGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Request a plan',
                  style: AppText.body(15, color: Colors.black, weight: FontWeight.w700),
                ),
                const SizedBox(width: 8),
                Container(width: 3, height: 3, decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.black45)),
                const SizedBox(width: 8),
                Text(
                  advisor.isFree ? 'Free' : '\$${advisor.pricePerPlan}',
                  style: AppText.body(15, color: Colors.black, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
