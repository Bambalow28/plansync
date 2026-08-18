import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../services/connectivity_service.dart';
import '../../services/unsplash_service.dart';
import '../../theme/app_theme.dart';

/// A destination backdrop: an Unsplash photo when there's a network and a key,
/// the supplied [gradient] otherwise. Used by both the trip cards and the
/// suggested-destinations carousel so the online/offline behaviour is defined
/// once.
///
/// The gradient is always painted underneath, so a slow or failed photo never
/// leaves a blank hole — it just stays on the app's existing look.
class DestinationPhoto extends StatefulWidget {
  /// Search text for the photo, e.g. "Kyoto Japan travel". Empty disables the
  /// lookup entirely (a trip with no destination yet).
  final String query;

  /// Fallback shown while loading, when offline, or when no photo is found.
  final List<Color> gradient;

  /// Painted over the photo — a scrim plus whatever text the card shows.
  final Widget child;

  /// Shows a small "offline" chip in the corner when there's no network.
  /// The trip cards leave this off (a gradient cover is their normal look);
  /// the carousel turns it on, since a photo is what it's meant to show.
  final bool showOfflineBadge;

  /// Dims the whole backdrop (past trips read as archived).
  final bool dimmed;

  const DestinationPhoto({
    super.key,
    required this.query,
    required this.gradient,
    required this.child,
    this.showOfflineBadge = false,
    this.dimmed = false,
  });

  @override
  State<DestinationPhoto> createState() => _DestinationPhotoState();
}

class _DestinationPhotoState extends State<DestinationPhoto> {
  bool _online = true;
  StreamSubscription<bool>? _connSub;
  String? _url;

  @override
  void initState() {
    super.initState();
    // A url the carousel (or an earlier card) already resolved paints on the
    // first frame — no gradient flash for anything prefetched.
    _url = UnsplashService.instance.cachedUrl(widget.query);
    // Start fetching straight away rather than waiting a hop for the
    // connectivity probe; offline just fails fast into the gradient.
    _load();
    _connSub = ConnectivityService.instance.onlineStream.listen(_setOnline);
    ConnectivityService.instance.isOnline().then(_setOnline);
  }

  @override
  void didUpdateWidget(DestinationPhoto old) {
    super.didUpdateWidget(old);
    if (widget.query != old.query) {
      _url = null;
      _load();
    }
  }

  void _setOnline(bool online) {
    if (!mounted) return;
    setState(() => _online = online);
    if (online) _load();
  }

  Future<void> _load() async {
    if (_url != null || widget.query.isEmpty) return;
    if (!UnsplashService.instance.isConfigured) return;
    final url = await UnsplashService.instance.photoUrl(widget.query);
    if (!mounted || url == null) return;
    setState(() => _url = url);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final showPhoto = _online && _url != null;
    return Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradient,
              ),
            ),
          ),
        ),
        if (showPhoto)
          Positioned.fill(
            // Archived trips keep their photo, just faded well back toward the
            // gradient underneath.
            child: Opacity(
              opacity: widget.dimmed ? 0.32 : 1,
              child: CachedNetworkImage(
                imageUrl: _url!,
                fit: BoxFit.cover,
                // Bytes already on disk paint with no transition at all; only
                // a genuine download fades in.
                fadeInDuration: const Duration(milliseconds: 300),
                fadeOutDuration: Duration.zero,
                placeholder: (_, _) => const SizedBox.shrink(),
                // A broken image just falls back to the gradient already below.
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        // Scrim: keeps text legible over an unpredictable photo. Weighted to
        // the bottom, where the display type sits, but never fully clear at
        // the top — the place label lives up there.
        if (showPhoto)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.45),
                    Colors.black.withValues(alpha: 0.28),
                    Colors.black.withValues(alpha: 0.78),
                  ],
                  stops: const [0, 0.35, 1],
                ),
              ),
            ),
          ),
        if (widget.showOfflineBadge && !_online)
          const Positioned(top: 12, right: 12, child: _OfflineChip()),
        widget.child,
      ],
    );
  }
}

/// Marks a card that would be showing a photo if there were a network.
class _OfflineChip extends StatelessWidget {
  const _OfflineChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded, size: 11, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text('Offline', style: AppText.label(9, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
