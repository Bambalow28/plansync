import 'dart:async';
import 'package:flutter/material.dart';
import '../../../data/suggested_places.dart';
import '../../../models/trip.dart';
import '../../../services/location_service.dart';
import '../../../services/unsplash_service.dart';
import '../../../theme/app_theme.dart';
import '../../shared/destination_photo.dart';
import '../../shared/plan_preview_sheet.dart';

/// Auto-advancing strip of curated destinations, ordered by what's in season
/// this month and biased toward the user's own region once (and if) a location
/// fix arrives. Tapping one starts a trip with that destination pre-filled.
class SuggestedCarousel extends StatefulWidget {
  const SuggestedCarousel({super.key});

  @override
  State<SuggestedCarousel> createState() => _SuggestedCarouselState();
}

const _kCardHeight = 168.0;
const _kAutoAdvance = Duration(seconds: 5);

/// How many cards ahead to warm. Each costs one Unsplash request against a
/// 50/hour demo-tier budget, so this stays well short of the full list.
const _kPrefetchCount = 6;

class _SuggestedCarouselState extends State<SuggestedCarousel> {
  final _controller = PageController(viewportFraction: 0.84);
  Timer? _timer;
  late List<SuggestedPlace> _places;
  double _page = 0;

  @override
  void initState() {
    super.initState();
    // Render immediately on the seasonal order; re-sort later if a location
    // turns up. Never block the home screen on a permission prompt.
    _places = suggestionsFor(month: DateTime.now().month);
    _controller.addListener(_onScroll);
    _startTimer();
    _prefetch();
    LocationService.instance.countryCode().then(_applyRegion);
  }

  void _applyRegion(String? countryCode) {
    final region = regionForCountry(countryCode);
    if (!mounted || region == null) return;
    setState(() {
      _places = suggestionsFor(month: DateTime.now().month, region: region);
    });
    // The reorder brings different cards to the front — warm those too.
    _prefetch();
  }

  /// Resolve and decode the photos for the cards the user is about to see, so
  /// they're already in the image cache when their card builds. Without this
  /// each card starts its own request only once it scrolls into view, which
  /// reads as a gradient that pops into a photo a beat later.
  void _prefetch() {
    if (!UnsplashService.instance.isConfigured) return;
    for (final place in _places.take(_kPrefetchCount)) {
      UnsplashService.instance.photoUrl(place.photoQuery).then((url) {
        if (!mounted || url == null) return;
        precacheImage(NetworkImage(url), context);
      });
    }
  }

  void _onScroll() {
    final page = _controller.page;
    if (page != null && page != _page) setState(() => _page = page);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_kAutoAdvance, (_) {
      if (!mounted || !_controller.hasClients || _places.isEmpty) return;
      final next = ((_controller.page ?? 0).round() + 1) % _places.length;
      _controller.animateToPage(
        next,
        // Wrapping back to the first card animates the whole way rather than
        // whipping backwards through every page.
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_places.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 20, 10),
          child: Text(
            'TRENDING THIS MONTH',
            style: AppText.label(11, color: AppColors.textMuted),
          ),
        ),
        SizedBox(
          height: _kCardHeight,
          // Touching the strip stops the auto-advance so it never yanks the
          // card out from under a finger; it resumes once the touch ends.
          child: Listener(
            onPointerDown: (_) => _timer?.cancel(),
            onPointerUp: (_) => _startTimer(),
            onPointerCancel: (_) => _startTimer(),
            child: PageView.builder(
              controller: _controller,
              itemCount: _places.length,
              padEnds: false,
              itemBuilder: (context, i) {
                // Cards ease down and back as they pass the centre.
                final distance = (_page - i).abs().clamp(0.0, 1.0);
                final scale = 1 - distance * 0.06;
                return Padding(
                  padding: const EdgeInsets.only(left: 20),
                  child: Transform.scale(
                    scale: scale,
                    child: _SuggestionCard(place: _places[i]),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final SuggestedPlace place;
  const _SuggestionCard({required this.place});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => PlanPreviewSheet.show(context, place),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: DestinationPhoto(
          query: place.photoQuery,
          gradient: tripCovers[place.cover]!,
          showOfflineBadge: true,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  place.city,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(24),
                ),
                const SizedBox(height: 4),
                Text(
                  place.tagline,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
