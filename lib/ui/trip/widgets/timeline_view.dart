import 'dart:async';
import 'package:flutter/material.dart';
import '../../../models/category.dart';
import '../../../models/itinerary_item.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';

/// Vertical day timeline.
///
/// The rail is built from time *anchors*. A "journey" — an item that spans days
/// or contains other items (e.g. a flight) — gets a **start node and an end
/// node** joined by a dashed, category-colored spine that runs its full
/// duration on the day (to END OF DAY when it carries into tomorrow, or down to
/// its arrival time on the day it lands). Items that happen *during* a journey
/// branch off the spine to the right, hugging their card. START / END OF DAY
/// bookend the day.
/// Renders one day's timeline as a non-scrolling column so it can sit inside a
/// larger page scroll. The reveal animation replays whenever [day] changes.
class TimelineView extends StatefulWidget {
  final List<ItineraryItem> items;
  final String currency;
  final ValueChanged<ItineraryItem> onTapItem;
  // Tapping a collapsed "N plans at the same time" card hands back the group.
  final ValueChanged<List<ItineraryItem>> onTapGroup;
  final DateTime day;

  const TimelineView({
    super.key,
    required this.items,
    required this.currency,
    required this.onTapItem,
    required this.onTapGroup,
    required this.day,
  });

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> with SingleTickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  // Ticks the "now" line forward while today's timeline is on screen; only
  // runs when it's actually needed (not on past/future days).
  Timer? _nowTimer;

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  void _syncNowTimer() {
    final needed = _isToday(widget.day);
    if (needed == (_nowTimer != null)) return;
    _nowTimer?.cancel();
    _nowTimer = needed ? Timer.periodic(const Duration(seconds: 60), (_) => setState(() {})) : null;
  }

  @override
  void initState() {
    super.initState();
    _syncNowTimer();
  }

  @override
  void didUpdateWidget(TimelineView old) {
    super.didUpdateWidget(old);
    // Replay the reveal when switching to a different day.
    if (old.day != widget.day) _intro.forward(from: 0);
    _syncNowTimer();
  }

  @override
  void dispose() {
    _intro.dispose();
    _nowTimer?.cancel();
    super.dispose();
  }

  /// Effective [start, end] of an item within this day; null if untimed.
  (DateTime, DateTime)? _eff(ItineraryItem item, DateTime ds, DateTime de) {
    if (item.start == null) return null;
    if (item.spansDays) {
      return (item.isStartDay(widget.day) ? item.start! : ds, item.isEndDay(widget.day) ? item.end! : de);
    }
    return (item.start!, item.end ?? item.start!);
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final day = widget.day;
    final currency = widget.currency;
    final onTapItem = widget.onTapItem;
    final onTapGroup = widget.onTapGroup;

    if (items.isEmpty) return const TimelineEmpty();

    final n = items.length;
    final now = DateTime.now();
    final ds = DateTime(day.year, day.month, day.day);
    final de = ds.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));
    final eff = [for (final it in items) _eff(it, ds, de)];

    // Timed items that share an exact start instant collapse into one card.
    final startGroups = <DateTime, List<int>>{};
    for (var i = 0; i < n; i++) {
      final e = eff[i];
      if (e != null) startGroups.putIfAbsent(e.$1, () => []).add(i);
    }
    final emittedGroups = <DateTime>{};

    // Timed items that end at the exact same instant (and don't hand off
    // straight into another plan's start) collapse into one end marker too —
    // otherwise they render as two stacked rows with nothing but a
    // zero-duration "gap" between them, which reads as a stray connecting line.
    final endGroups = <DateTime, List<int>>{};
    for (var i = 0; i < n; i++) {
      final e = eff[i];
      if (e == null || !e.$2.isAfter(e.$1) || !e.$2.isBefore(de)) continue;
      final meetsNext = eff.any((x) => x != null && x.$1 == e.$2);
      if (meetsNext) continue;
      endGroups.putIfAbsent(e.$2, () => []).add(i);
    }
    final emittedEndGroups = <DateTime>{};

    Duration dur(int i) => eff[i]!.$2.difference(eff[i]!.$1);

    // The longest *other* item whose interval fully covers item i. When two
    // items share the same interval, the earlier index wins so exactly one is
    // the container (fixes: at a shared start time the longer plan is the main
    // spine and the shorter one branches off it).
    int? containerOf(int i) {
      final e = eff[i];
      if (e == null) return null;
      // A day-spanning journey (e.g. a red-eye that runs into tomorrow) is
      // always its own trunk, never a branch — so its colored spine draws down
      // to END OF DAY on its start day rather than dangling off another plan.
      if (items[i].spansDays) return null;
      int? best;
      for (var j = 0; j < n; j++) {
        if (j == i) continue;
        final ej = eff[j];
        if (ej == null) continue;
        final covers = !ej.$1.isAfter(e.$1) && !ej.$2.isBefore(e.$2);
        if (!covers) continue;
        final longer = dur(j) > dur(i) || (dur(j) == dur(i) && j < i);
        if (!longer) continue;
        if (best == null || dur(j) > dur(best)) best = j;
      }
      return best;
    }

    final container = [for (var i = 0; i < n; i++) containerOf(i)];
    final nested = [for (var i = 0; i < n; i++) container[i] != null];
    // Every top-level plan with real duration owns a colored spine over its
    // interval. Zero-duration plans (start == end) get a dot only — no spine.
    final spines = [
      for (var i = 0; i < n; i++)
        if (!nested[i] && eff[i] != null && eff[i]!.$2.isAfter(eff[i]!.$1)) i
    ];

    // Line style across (ta, tb): dashed + colored if a journey covers it.
    _Line seg(DateTime ta, DateTime tb) {
      // ta == tb is a real rail segment between two stacked same-time nodes
      // (e.g. two plans starting at 6:53) — still color it if a spine covers
      // that instant, so the trunk plan connects to its own line.
      if (ta.isAfter(tb)) return _Line.faint;
      int? best;
      for (final k in spines) {
        final e = eff[k]!;
        if (!e.$1.isAfter(ta) && !e.$2.isBefore(tb)) {
          if (best == null || e.$2.isAfter(eff[best]!.$2)) best = k;
        }
      }
      if (best == null) return _Line.faint;
      // Every plan's spine is dotted; only the elbow out to a branched-off
      // plan is solid. Grey (faint) means free time between plans.
      return _Line(styleOf(items[best].category).color.withValues(alpha: 0.75), true);
    }

    // A plan is "done" once its end has passed.
    bool doneOf(int i) => eff[i] != null && eff[i]!.$2.isBefore(now);

    // Build anchors.
    final anchors = <_Anchor>[
      _Anchor(
        time: ds,
        order: 0,
        gutter: const _Gutter(time: '12:00', period: 'AM'),
        content: const _BookendContent(label: 'START OF DAY', time: '12:00 AM'),
        nodeColor: AppColors.accent,
      ),
    ];
    for (var i = 0; i < n; i++) {
      final e = eff[i];
      final color = styleOf(items[i].category).color;
      if (e == null) continue;
      final group = startGroups[e.$1]!;
      if (group.length >= 2) {
        // Collapse the whole same-start group into one card, emitted once. The
        // node/spine use the trunk (the non-nested plan that owns the spine).
        if (emittedGroups.add(e.$1)) {
          final trunk = group.firstWhere((j) => !nested[j], orElse: () => group.first);
          final groupItems = [for (final j in group) items[j]];
          anchors.add(_Anchor(
            time: e.$1,
            order: 2,
            gutter: _gutterFor(items[trunk]),
            content: _MultiPlanCard(items: groupItems, onTap: () => onTapGroup(groupItems)),
            nodeColor: styleOf(items[trunk].category).color,
            done: group.every(doneOf),
          ));
        }
      } else {
        anchors.add(_Anchor(
          time: e.$1,
          order: 2,
          gutter: _gutterFor(items[i]),
          content: _EventCard(item: items[i], day: day, currency: currency, onTap: () => onTapItem(items[i])),
          nodeColor: color,
          branch: nested[i],
          done: doneOf(i),
        ));
      }
      // Explicit end node for every plan whose end doesn't land exactly where
      // the next plan starts (that shared instant becomes a single handoff
      // dot instead — no need for two markers on top of each other). A
      // top-level plan's end stops its colored line (so free time after it
      // reads as grey); a nested/overlapping plan's end renders as a side
      // label off the trunk's spine, same as its start branch. Plans that end
      // at the exact same instant collapse into one marker (tap for both).
      final meetsNext = eff.any((x) => x != null && x.$1 == e.$2);
      if (e.$2.isAfter(e.$1) && e.$2.isBefore(de) && !meetsNext) {
        final endGroup = endGroups[e.$2]!;
        if (endGroup.length >= 2) {
          if (emittedEndGroups.add(e.$2)) {
            final groupItems = [for (final j in endGroup) items[j]];
            final trunk = endGroup.firstWhere((j) => !nested[j], orElse: () => endGroup.first);
            anchors.add(_Anchor(
              time: e.$2,
              order: 1,
              gutter: _gutterAt(e.$2),
              content: _MultiEndContent(items: groupItems, onTap: () => onTapGroup(groupItems)),
              nodeColor: styleOf(items[trunk].category).color,
              filled: true,
              done: endGroup.every(doneOf),
            ));
          }
        } else {
          anchors.add(_Anchor(
            time: e.$2,
            order: 1,
            gutter: _gutterAt(e.$2),
            content: _EndContent(item: items[i]),
            nodeColor: color,
            filled: true,
            branch: nested[i],
            done: doneOf(i),
          ));
        }
      }
    }
    for (var i = 0; i < n; i++) {
      if (eff[i] != null) continue;
      anchors.add(_Anchor(
        time: de,
        order: 3,
        gutter: const _Gutter(time: 'Any', period: ''),
        content: _EventCard(item: items[i], day: day, currency: currency, onTap: () => onTapItem(items[i])),
        nodeColor: styleOf(items[i].category).color,
      ));
    }
    anchors.add(_Anchor(
      time: de,
      order: 4,
      gutter: const _Gutter(time: '11:59', period: 'PM'),
      content: const _BookendContent(label: 'END OF DAY', time: '11:59 PM'),
      nodeColor: AppColors.accent,
    ));

    // A trip in progress gets a live marker at the current moment — purely a
    // visual overlay row, not a real plan, so it never affects the
    // spine/container/branch math above. When "now" lands on the same minute
    // as an existing plan node, that would-be marker's line/label are
    // redundant with the plan already sitting right there — recolor that
    // node instead of drawing a second one on top of it.
    if (_isToday(day)) {
      final nowClamped = now.isBefore(ds) ? ds : (now.isAfter(de) ? de : now);
      final nowMinute = nowClamped.hour * 60 + nowClamped.minute;
      final hitIndex = anchors.indexWhere((a) => a.time.hour * 60 + a.time.minute == nowMinute);
      if (hitIndex != -1) {
        anchors[hitIndex] = anchors[hitIndex].copyWith(nodeColor: AppColors.warning, filled: true);
      } else {
        anchors.add(_Anchor(
          time: nowClamped,
          order: 2,
          gutter: const SizedBox.shrink(),
          content: _NowContent(time: timeLabel(nowClamped.hour * 60 + nowClamped.minute)),
          nodeColor: AppColors.warning,
          filled: true,
        ));
      }
    }

    anchors.sort((a, b) {
      final c = a.time.compareTo(b.time);
      if (c != 0) return c;
      final o = a.order.compareTo(b.order);
      if (o != 0) return o;
      // At the same time, a trunk renders above the plans branching off it.
      return (a.branch ? 1 : 0).compareTo(b.branch ? 1 : 0);
    });

    final count = anchors.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var m = 0; m < count; m++)
            _RailRow(
              // Plans that start at the same time stack under a single time
              // label — don't repeat the gutter time for the ones beneath.
              gutter: (m > 0 && anchors[m].time == anchors[m - 1].time)
                  ? const SizedBox.shrink()
                  : anchors[m].gutter,
              content: anchors[m].content,
              nodeColor: anchors[m].nodeColor,
              filled: anchors[m].filled,
              branch: anchors[m].branch,
              done: anchors[m].done,
              above: m == 0 ? _Line.none : seg(anchors[m - 1].time, anchors[m].time),
              below: m == count - 1 ? _Line.none : seg(anchors[m].time, anchors[m + 1].time),
              reveal: _rowReveal(m, count),
            ),
        ],
      ),
    );
  }

  /// Per-row reveal animation, staggered top-to-bottom over [_intro].
  Animation<double> _rowReveal(int index, int count) {
    const window = 0.5;
    final n = count <= 1 ? 1 : count;
    final start = (index / n) * (1 - window);
    return CurvedAnimation(
      parent: _intro,
      curve: Interval(start.clamp(0.0, 1 - window), (start + window).clamp(0.0, 1.0)),
    );
  }

  _Gutter _gutterFor(ItineraryItem item) {
    if (item.start == null) return const _Gutter(time: 'Any', period: '');
    if (item.spansDays && item.isEndDay(widget.day)) return const _Gutter(time: '12:00', period: 'AM');
    return _gutterAt(item.start!);
  }

  _Gutter _gutterAt(DateTime t) {
    final parts = timeLabel(t.hour * 60 + t.minute).split(' ');
    return _Gutter(time: parts[0], period: parts.length > 1 ? parts[1] : '');
  }
}

class _Anchor {
  final DateTime time;
  final int order; // tie-break at equal time: bookendStart<itemEnd<itemStart<untimed<bookendEnd
  final Widget gutter;
  final Widget content;
  final Color nodeColor;
  final bool filled;
  final bool branch;
  final bool done;
  const _Anchor({
    required this.time,
    required this.order,
    required this.gutter,
    required this.content,
    required this.nodeColor,
    this.filled = false,
    this.branch = false,
    this.done = false,
  });

  _Anchor copyWith({Color? nodeColor, bool? filled}) => _Anchor(
    time: time,
    order: order,
    gutter: gutter,
    content: content,
    nodeColor: nodeColor ?? this.nodeColor,
    filled: filled ?? this.filled,
    branch: branch,
    done: done,
  );
}

class _Line {
  final Color color;
  final bool dashed;
  const _Line(this.color, this.dashed);
  static const faint = _Line(Color(0x14FFFFFF), false);
  static const none = _Line(Color(0x00000000), false);
}

class _RailRow extends StatelessWidget {
  final Widget gutter;
  final Widget content;
  final Color nodeColor;
  final _Line above;
  final _Line below;
  final bool branch;
  final bool filled;
  final bool done;

  /// Drives the entrance: line extends downward, node + card pop in.
  final Animation<double>? reveal;

  const _RailRow({
    required this.gutter,
    required this.content,
    required this.nodeColor,
    required this.above,
    required this.below,
    this.branch = false,
    this.filled = false,
    this.done = false,
    this.reveal,
  });

  static const _railX = 12.0;
  static const _branchX = 48.0; // nested node sits well right of the rail
  static const _railW = 28.0;
  static const _branchIndent = 30.0; // extra left padding for a nested card
  static const _nodeTop = 18.0;
  static const _nodeCenter = 25.0; // _nodeTop + 7

  @override
  Widget build(BuildContext context) {
    if (reveal == null) return _frame(1, 1, 1, 1);
    return AnimatedBuilder(
      animation: reveal!,
      builder: (context, _) {
        final v = reveal!.value.clamp(0.0, 1.0);
        return _frame(
          Curves.easeOut.transform(v), // opacity
          Curves.easeOutCubic.transform(v), // line extend 0..1
          Curves.easeOutBack.transform(v).clamp(0.0, 2.0), // node pop (overshoot)
          0.82 + 0.18 * Curves.easeOutBack.transform(v), // card balloon scale
        );
      },
    );
  }

  Widget _frame(double op, double lineT, double nodePop, double cardScale) {
    final nodeX = branch ? _branchX : _railX;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 50, child: Opacity(opacity: op, child: gutter)),
          SizedBox(
            width: _railW,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: _railX - 1,
                  top: 0,
                  child: Opacity(
                    opacity: op,
                    // Anchored to its bottom — that's this row's node, so a
                    // dash always touches it. The seam at the top (where this
                    // meets the row above's "below" piece) floats naturally.
                    child: SizedBox(width: 2, height: _nodeCenter, child: _segment(above, anchorBottom: true)),
                  ),
                ),
                // Below-line clips from the top so it appears to draw downward.
                Positioned(
                  left: _railX - 1,
                  top: _nodeCenter,
                  bottom: 0,
                  child: ClipRect(
                    clipper: _RevealClipper(lineT),
                    // Anchored to its top — this row's node — so the seam at
                    // the bottom (shared with the next row's "above" piece)
                    // floats instead of always meeting nose-to-nose.
                    child: SizedBox(width: 2, child: _segment(below, anchorBottom: false)),
                  ),
                ),
                if (branch)
                  // Elbow from the main rail out to the branch node. The
                  // branched plan hugs its card — it does NOT draw its own
                  // vertical line downward (that would dangle into the free
                  // space below with nothing to connect to).
                  Positioned(
                    left: _railX,
                    top: _nodeCenter - 1,
                    child: Opacity(
                      opacity: op,
                      child: Container(
                        width: _branchX - _railX,
                        height: 2,
                        color: nodeColor.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                Positioned(
                  left: nodeX - 7,
                  top: _nodeTop,
                  child: Transform.scale(scale: nodePop, child: _Node(color: nodeColor, filled: filled, done: done)),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: branch ? _branchIndent : 0, bottom: 14),
              child: Opacity(
                opacity: op,
                child: Transform.scale(scale: cardScale, alignment: Alignment.centerLeft, child: content),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _segment(_Line line, {required bool anchorBottom}) {
    if (line.color.a == 0) return const SizedBox.shrink();
    return line.dashed
        ? _DashedLine(color: line.color, anchorBottom: anchorBottom)
        : Container(width: 2, color: line.color);
  }
}

/// Clips a child to its top [t] fraction — used to "draw" the rail line down.
class _RevealClipper extends CustomClipper<Rect> {
  final double t;
  const _RevealClipper(this.t);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height * t.clamp(0.0, 1.0));
  @override
  bool shouldReclip(_RevealClipper old) => old.t != t;
}

class _Node extends StatelessWidget {
  final Color color;
  final bool filled;
  final bool done;
  const _Node({required this.color, this.filled = false, this.done = false});

  @override
  Widget build(BuildContext context) {
    // A completed plan reads as a filled circle with a check mark.
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (filled || done) ? color : AppColors.background,
        border: Border.all(color: color, width: 2.5),
      ),
      child: done
          ? Icon(Icons.check_rounded, size: 9, color: AppColors.background)
          : null,
    );
  }
}

class _Gutter extends StatelessWidget {
  final String time;
  final String period;
  const _Gutter({required this.time, required this.period});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, right: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(time, style: AppText.label(12, color: AppColors.textSecondary, tracking: 0.2)),
          if (period.isNotEmpty)
            Text(period, style: AppText.label(9, color: AppColors.textMuted, tracking: 0.5)),
        ],
      ),
    );
  }
}

class _BookendContent extends StatelessWidget {
  final String label;
  final String time;
  const _BookendContent({required this.label, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label(10, color: AppColors.accent, tracking: 1.5)),
          const SizedBox(height: 2),
          Text(time, style: AppText.label(11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Live marker for the current moment on today's rail — a warning-colored
/// line running into the content column with a small "NOW" label.
class _NowContent extends StatelessWidget {
  final String time;
  const _NowContent({required this.time});

  // Matches _RailRow._nodeCenter (its node's own vertical center, _nodeTop 18
  // + half the 14px node) so the line meets the dot instead of floating
  // above/below it — a plain Row here centers on its own text height, which
  // isn't the same number.
  static const _lineY = 25.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: _lineY - 7.5,
            left: 0,
            right: 0,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text('NOW · $time', style: AppText.label(10, color: AppColors.warning, tracking: 0.8)),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(height: 1, color: AppColors.warning.withValues(alpha: 0.65)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Terminal marker shown where a journey ends (e.g. a flight's arrival).
class _EndContent extends StatelessWidget {
  final ItineraryItem item;
  const _EndContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final s = styleOf(item.category);
    final isTravel = item.category == PlanCategory.flight || item.category == PlanCategory.transport;
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isTravel ? 'ARRIVES' : 'ENDS', style: AppText.label(10, color: s.color, tracking: 1.5)),
          const SizedBox(height: 2),
          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.label(11, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// Terminal marker for 2+ plans that end at the same instant. Tapping opens
/// the same swipeable read-only view as [_MultiPlanCard].
class _MultiEndContent extends StatelessWidget {
  final List<ItineraryItem> items;
  final VoidCallback onTap;
  const _MultiEndContent({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(top: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${items.length} PLANS END', style: AppText.label(10, color: AppColors.accent, tracking: 1.5)),
            const SizedBox(height: 2),
            Text(
              items.map((i) => i.title).join(' · '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.label(11, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  final ItineraryItem item;
  final DateTime day;
  final String currency;
  final VoidCallback onTap;

  const _EventCard({required this.item, required this.day, required this.currency, required this.onTap});

  String get _rangeLabel {
    if (item.start == null) return '';
    if (!item.spansDays) {
      if (item.end == null) return timeLabel(item.startMinutes!);
      return '${timeLabel(item.startMinutes!)} – ${timeLabel(item.endMinutes!)}';
    }
    if (item.isStartDay(day)) return '${timeLabel(item.startMinutes!)} – ${timeLabel(item.endMinutes!)} (Next day)';
    if (item.isEndDay(day)) return '12:00 AM – ${timeLabel(item.endMinutes!)}';
    return 'All day';
  }

  String get _flightLine {
    String code(String? iata, ItineraryItem it, {required bool arrival}) {
      final c = iata?.trim();
      if (c != null && c.isNotEmpty) return c.toUpperCase();
      final p = arrival ? it.arrivalLocation : it.location;
      return p?.label.split(',').first.trim() ?? '';
    }
    final from = code(item.departureCode, item, arrival: false);
    final to = code(item.arrivalCode, item, arrival: true);
    final route = (from.isNotEmpty || to.isNotEmpty) ? '$from → $to' : '';
    final fc = item.flightCode?.trim();
    if (fc != null && fc.isNotEmpty && route.isNotEmpty) return '$fc · $route';
    return fc != null && fc.isNotEmpty ? fc : route;
  }

  @override
  Widget build(BuildContext context) {
    final s = styleOf(item.category);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CategoryPill(style: s),
                const Spacer(),
                if (item.cost > 0)
                  Text(money(item.cost, currency), style: AppText.label(12, color: AppColors.textSecondary)),
              ],
            ),
            const SizedBox(height: 10),
            Text(item.title, style: AppText.body(16, weight: FontWeight.w600)),
            if (_rangeLabel.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(_rangeLabel, style: AppText.label(10, color: AppColors.textMuted)),
            ],
            if (item.isFlight && _flightLine.isNotEmpty) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(Icons.flight_rounded, size: 13, color: s.color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      _flightLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.label(11, color: AppColors.textSecondary, tracking: 0.3),
                    ),
                  ),
                ],
              ),
            ],
            if (item.hasLocation && !item.isFlight) ...[
              const SizedBox(height: 7),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 13, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      item.locationLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(13, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ],
            if (item.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.attach_file_rounded, size: 13, color: AppColors.accent),
                  const SizedBox(width: 4),
                  Text(
                    '${item.attachments.length} document${item.attachments.length == 1 ? '' : 's'}',
                    style: AppText.label(10, color: AppColors.accent),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Collapsed card for 2+ plans that start at the same time. Generic header +
/// a compact line per plan; tapping opens the swipeable read-only view.
class _MultiPlanCard extends StatelessWidget {
  final List<ItineraryItem> items;
  final VoidCallback onTap;
  const _MultiPlanCard({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.layers_rounded, size: 16, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('${items.length} plans at this time', style: AppText.body(15, weight: FontWeight.w700)),
              ],
            ),
            for (final it in items) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  _CategoryPill(style: styleOf(it.category)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      it.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(14, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.swipe_rounded, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 5),
                Text('Tap to view — swipe between them', style: AppText.label(10, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final CategoryStyle style;
  const _CategoryPill({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: 5),
          Text(style.label.toUpperCase(), style: AppText.label(8, color: style.color, tracking: 1)),
        ],
      ),
    );
  }
}

class _DashedLine extends StatelessWidget {
  final Color color;
  final bool anchorBottom;
  const _DashedLine({required this.color, required this.anchorBottom});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      child: CustomPaint(painter: _DashPainter(color, anchorBottom), child: const SizedBox.expand()),
    );
  }
}

/// One dash's [start, end] distance from this piece's own node (0 = right at
/// the node). Exposed at package visibility so its math can be asserted by a
/// test without pulling in widget rendering.
class DashSpan {
  final double start;
  final double end;
  const DashSpan(this.start, this.end);
}

const dashLen = 3.5, dashTargetGap = 5.0, dashSeamGap = dashTargetGap / 2;

/// Fits whole dashes into a piece of height [h], anchored at distance 0 (this
/// piece's own node), always reserving exactly [dashSeamGap] of blank space
/// at the far (seam) end — see [_DashPainter.paint] for why.
List<DashSpan> fitDashes(double h) {
  const period = dashLen + dashTargetGap;
  if (h <= 0) return const [];
  final usable = (h - dashSeamGap).clamp(0.0, h);
  if (usable <= 0) return const [];

  var d = dashLen;
  var g = 0.0;
  int count;
  if (usable <= dashLen) {
    // Too short for even one full-length dash — draw a single stub spanning
    // the whole usable space so it still ends exactly at the seam gap.
    count = 1;
    d = usable;
  } else {
    // Enough dashes that the internal gap never exceeds the target — using a
    // plain round() here can leave just 2 dashes sharing all the slack as one
    // oversized gap (e.g. h=15 → one ~5.5px gap instead of ~5px).
    count = ((usable + dashTargetGap) / period).ceil();
    if (count < 2) count = 2;
    if (count * d > usable) d = usable / count * (dashLen / period);
    g = (usable - count * d) / (count - 1);
  }

  return [
    for (var i = 0; i < count; i++)
      DashSpan(i * (d + g), (i * (d + g) + d).clamp(0.0, usable)),
  ];
}

class _DashPainter extends CustomPainter {
  final Color color;
  final bool anchorBottom;
  _DashPainter(this.color, this.anchorBottom);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final h = size.height;
    final x = size.width / 2;

    // Each connector between two nodes is drawn as two independent pieces —
    // the row above's "below" half and the row below's "above" half — that
    // meet at the seam between rows. Forcing a dash to land exactly at BOTH
    // ends of each piece guaranteed the pieces touch nose-to-nose at every
    // seam (reads as one merged line). Letting the far end float naturally
    // instead left a gap of unpredictable size there, varying with each row's
    // height. fitDashes() always reserves exactly half a normal gap as blank
    // space at the seam-facing end, so two abutting pieces combine into one
    // normal-sized gap at the seam — never a touch, never oversized.
    for (final span in fitDashes(h)) {
      if (anchorBottom) {
        canvas.drawLine(Offset(x, h - span.start), Offset(x, h - span.end), paint);
      } else {
        canvas.drawLine(Offset(x, span.start), Offset(x, span.end), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color || old.anchorBottom != anchorBottom;
}

/// Empty-day placeholder. Centered horizontally; the parent decides vertical
/// placement (the trip screen centers it in the remaining space).
class TimelineEmpty extends StatelessWidget {
  const TimelineEmpty({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_note_rounded, size: 36, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text('Nothing planned', style: AppText.body(16, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Text('Tap + to add to this day', textAlign: TextAlign.center, style: AppText.body(13, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
