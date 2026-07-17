import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Horizontal strip of day chips. Selecting a day filters the timeline; the
/// selected chip cross-fades its fill (no janky gradient tween) and the strip
/// auto-scrolls to keep the selected chip in view.
class DaySelector extends StatefulWidget {
  final List<DateTime> days;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  /// Map of day-index → number of planned items, for the little count dot.
  final List<int> counts;

  const DaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.onSelect,
    required this.counts,
  });

  @override
  State<DaySelector> createState() => _DaySelectorState();
}

class _DaySelectorState extends State<DaySelector> {
  final _controller = ScrollController();
  static const _itemExtent = 58.0 + 10.0; // chip width + separator

  @override
  void initState() {
    super.initState();
    // On first open, jump the strip to the selected day (e.g. today) so it's
    // visible without animation.
    if (widget.selectedIndex > 0) _ensureVisible(animate: false);
  }

  @override
  void didUpdateWidget(DaySelector old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) _ensureVisible();
  }

  void _ensureVisible({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_controller.hasClients) return;
      final viewport = _controller.position.viewportDimension;
      // Center the selected chip (account for the strip's 20px leading pad).
      const lead = 20.0, chipWidth = 58.0;
      final chipCenter = lead + widget.selectedIndex * _itemExtent + chipWidth / 2;
      final target = chipCenter - viewport / 2;
      final clamped = target.clamp(0.0, _controller.position.maxScrollExtent);
      if (animate) {
        _controller.animateTo(clamped, duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
      } else {
        _controller.jumpTo(clamped);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: ListView.separated(
        controller: _controller,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: widget.days.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final d = widget.days[i];
          final now = DateTime.now();
          final isPast = DateTime(d.year, d.month, d.day)
              .isBefore(DateTime(now.year, now.month, now.day));
          return _DayChip(
            day: d,
            selected: i == widget.selectedIndex,
            hasItems: widget.counts[i] > 0,
            isPast: isPast,
            onTap: () => widget.onSelect(i),
          );
        },
      ),
    );
  }
}

class _DayChip extends StatefulWidget {
  final DateTime day;
  final bool selected;
  final bool hasItems;
  final bool isPast;
  final VoidCallback onTap;

  const _DayChip({
    required this.day,
    required this.selected,
    required this.hasItems,
    required this.isPast,
    required this.onTap,
  });

  @override
  State<_DayChip> createState() => _DayChipState();
}

class _DayChipState extends State<_DayChip> {
  bool _pressed = false;

  static const _fade = Duration(milliseconds: 220);
  static const _curve = Curves.easeOutCubic;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    final weekdayColor = selected ? Colors.black.withValues(alpha: 0.7) : AppColors.textMuted;
    final numColor = selected ? Colors.black : Colors.white;
    final markColor = widget.hasItems
        ? (selected ? Colors.black.withValues(alpha: 0.6) : AppColors.accent)
        : Colors.transparent;
    // A past day with plans reads as "done" — a check instead of the dot.
    final showCheck = widget.hasItems && widget.isPast;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.9 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: 58,
          child: Stack(
            children: [
              // Base (unselected look) — always present.
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                  ),
                ),
              ),
              // Selected fill — cross-faded in/out (opacity tween is smooth,
              // unlike animating a gradient to/from null).
              Positioned.fill(
                child: AnimatedOpacity(
                  opacity: selected ? 1 : 0,
                  duration: _fade,
                  curve: _curve,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: AppColors.accent.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                  ),
                ),
              ),
              // Content.
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: _fade,
                      curve: _curve,
                      style: AppText.label(9, color: weekdayColor),
                      child: Text(dayWeekday(widget.day).toUpperCase()),
                    ),
                    const SizedBox(height: 4),
                    AnimatedDefaultTextStyle(
                      duration: _fade,
                      curve: _curve,
                      style: AppText.display(22, color: numColor),
                      child: Text(dayNum(widget.day)),
                    ),
                    const SizedBox(height: 5),
                    SizedBox(
                      height: 8,
                      child: showCheck
                          ? Icon(Icons.check_rounded, size: 9, color: markColor)
                          : AnimatedContainer(
                              duration: _fade,
                              curve: _curve,
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: markColor),
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
