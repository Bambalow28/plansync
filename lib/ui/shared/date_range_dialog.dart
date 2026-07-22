import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// A compact date-range picker dialog — unlike [showDateRangePicker], which
/// defaults to a full-screen page on mobile and has no theming hook for
/// in-range day text (see git history), this draws every cell itself, so
/// colors are exactly what we say and never fall back to framework defaults.
/// Height is whatever the displayed month actually needs (4-6 week rows),
/// not a fixed reservation for the longest possible month.
Future<DateTimeRange?> showAppDateRangeDialog({
  required BuildContext context,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? initialStart,
  DateTime? initialEnd,
}) {
  return showDialog<DateTimeRange>(
    context: context,
    builder: (_) => _DateRangeDialog(
      firstDate: firstDate,
      lastDate: lastDate,
      initialStart: initialStart,
      initialEnd: initialEnd,
    ),
  );
}

class _DateRangeDialog extends StatefulWidget {
  final DateTime firstDate;
  final DateTime lastDate;
  final DateTime? initialStart;
  final DateTime? initialEnd;
  const _DateRangeDialog({
    required this.firstDate,
    required this.lastDate,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<_DateRangeDialog> createState() => _DateRangeDialogState();
}

const _kWeekdayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
const _kMonthNames = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

class _DateRangeDialogState extends State<_DateRangeDialog> {
  late DateTime _month;
  DateTime? _start;
  DateTime? _end;

  @override
  void initState() {
    super.initState();
    _start = widget.initialStart;
    _end = widget.initialEnd;
    var anchor = _start ?? DateTime.now();
    if (anchor.isBefore(widget.firstDate)) anchor = widget.firstDate;
    if (anchor.isAfter(widget.lastDate)) anchor = widget.lastDate;
    _month = DateTime(anchor.year, anchor.month);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _tap(DateTime day) {
    setState(() {
      if (_start == null || _end != null) {
        _start = day;
        _end = null;
      } else if (day.isBefore(_start!)) {
        _end = _start;
        _start = day;
      } else {
        _end = day;
      }
    });
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
  }

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final firstWeekday = DateTime(_month.year, _month.month, 1).weekday % 7; // 0=Sun
    final weeks = ((firstWeekday + daysInMonth) / 7).ceil();

    final firstMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final lastMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    final canGoPrev = _month.isAfter(firstMonth);
    final canGoNext = _month.isBefore(lastMonth);

    return Dialog(
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: canGoPrev ? () => _changeMonth(-1) : null,
                  icon: Icon(
                    Icons.chevron_left_rounded,
                    color: canGoPrev ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
                Expanded(
                  child: Text(
                    '${_kMonthNames[_month.month - 1]} ${_month.year}',
                    textAlign: TextAlign.center,
                    style: AppText.display(18),
                  ),
                ),
                IconButton(
                  onPressed: canGoNext ? () => _changeMonth(1) : null,
                  icon: Icon(
                    Icons.chevron_right_rounded,
                    color: canGoNext ? AppColors.textPrimary : AppColors.textMuted,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                for (final w in _kWeekdayLabels)
                  Expanded(
                    child: Center(
                      child: Text(w, style: AppText.label(11, color: AppColors.textMuted)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var week = 0; week < weeks; week++)
              Row(
                children: [
                  for (var wd = 0; wd < 7; wd++)
                    Expanded(child: _dayCell(week * 7 + wd, firstWeekday, daysInMonth)),
                ],
              ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
                ),
                TextButton(
                  onPressed: (_start != null && _end != null)
                      ? () => Navigator.pop(context, DateTimeRange(start: _start!, end: _end!))
                      : null,
                  child: Text(
                    'Save',
                    style: AppText.body(
                      14,
                      color: (_start != null && _end != null) ? AppColors.accent : AppColors.textMuted,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayCell(int cellIndex, int firstWeekday, int daysInMonth) {
    final dayNum = cellIndex - firstWeekday + 1;
    if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox(height: 38);

    final day = DateTime(_month.year, _month.month, dayNum);
    final disabled = day.isBefore(widget.firstDate) || day.isAfter(widget.lastDate);
    final isStart = _start != null && _sameDay(day, _start!);
    final isEnd = _end != null && _sameDay(day, _end!);
    final isEndpoint = isStart || isEnd;
    final inRange = _start != null && _end != null && day.isAfter(_start!) && day.isBefore(_end!);
    final isToday = _sameDay(day, DateTime.now());

    return GestureDetector(
      onTap: disabled ? null : () => _tap(day),
      child: Container(
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 2),
        // The in-range wash spans the whole (non-square) cell, so it stays a
        // rectangle; the endpoint/today marker is a fixed-size circle below
        // instead of relying on BoxShape.circle on this wide/short cell,
        // which would render as an oval rather than a true circle.
        color: (!isEndpoint && inRange) ? AppColors.accent.withValues(alpha: 0.18) : null,
        child: Center(
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isEndpoint ? AppColors.accent : null,
              shape: BoxShape.circle,
              border: (isToday && !isEndpoint) ? Border.all(color: AppColors.accent, width: 1.5) : null,
            ),
            child: Center(
              child: Text(
                '$dayNum',
                style: AppText.body(
                  13,
                  color: disabled
                      ? AppColors.textMuted.withValues(alpha: 0.5)
                      : isEndpoint
                          ? Colors.black
                          : AppColors.textPrimary,
                  weight: isEndpoint ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
