import 'package:flutter/material.dart';

/// Fades and rises a list item into place, staggered by its index.
class EntranceFade extends StatelessWidget {
  final int index;
  final Widget child;
  const EntranceFade({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      // Later items start later, but the stagger stops growing after a
      // handful so a long list doesn't leave the last item waiting seconds
      // to appear.
      duration: Duration(milliseconds: 380 + 70 * (index.clamp(0, 5))),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}
