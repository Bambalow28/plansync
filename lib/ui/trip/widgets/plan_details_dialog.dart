import 'package:flutter/material.dart';
import '../../../controllers/trip_controller.dart';
import '../../../models/category.dart';
import '../../../models/itinerary_item.dart';
import '../../../models/trip.dart';
import '../../../services/attachment_service.dart';
import '../../../services/connectivity_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../shared/add_item_sheet.dart';
import 'flight_card.dart';

/// A compact, read-only view of a plan. Shows only the fields that are filled
/// in (with "Free" / "No notes" fallbacks). Editing happens in [AddItemSheet],
/// which this opens in edit mode.
class PlanDetailsDialog extends StatelessWidget {
  final Trip trip;
  final DateTime day;
  final ItineraryItem item;
  final bool offline;

  const PlanDetailsDialog({
    super.key,
    required this.trip,
    required this.day,
    required this.item,
    this.offline = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required DateTime day,
    required ItineraryItem item,
  }) async {
    // For flights, live data quality depends on being online — note it if not.
    final offline = item.isFlight ? !(await ConnectivityService.instance.isOnline()) : false;
    if (!context.mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (_) => PlanDetailsDialog(trip: trip, day: day, item: item, offline: offline),
    );
    if (!context.mounted) return;
    await runAction(context, trip, day, item, action);
  }

  /// Dispatches an 'edit' / 'delete' action returned by a details view.
  /// Shared by [PlanDetailsDialog] and [PlanGroupDialog].
  static Future<void> runAction(
      BuildContext context, Trip trip, DateTime day, ItineraryItem item, String? action) async {
    if (action == 'edit' && context.mounted) {
      AddItemSheet.show(context, trip: trip, day: day, existing: item, startEditing: true);
    } else if (action == 'delete' && context.mounted) {
      await _confirmAndDelete(context, trip, item);
    }
  }

  static Future<void> _confirmAndDelete(BuildContext context, Trip trip, ItineraryItem item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Delete plan?', style: AppText.display(20)),
        content: Text(
          '“${item.title}” will be removed from this day.',
          style: AppText.body(14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: AppText.body(14, color: AppColors.warning)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await AttachmentService.instance.deleteAll(item.attachments);
    await TripController.instance.deleteItem(trip.id, item.id);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surfaceHigh,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: SingleChildScrollView(
          child: PlanDetailBody(
            trip: trip,
            day: day,
            item: item,
            offline: offline,
            onEdit: () => Navigator.pop(context, 'edit'),
            onDelete: () => Navigator.pop(context, 'delete'),
          ),
        ),
      ),
    );
  }
}

/// A read-only, swipeable view of several plans that share a start time.
/// Each page is a [PlanDetailBody]; Edit/Delete on a page dispatch for that
/// specific plan.
class PlanGroupDialog extends StatefulWidget {
  final Trip trip;
  final DateTime day;
  final List<ItineraryItem> items;
  final bool offline;

  const PlanGroupDialog({
    super.key,
    required this.trip,
    required this.day,
    required this.items,
    this.offline = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required DateTime day,
    required List<ItineraryItem> items,
  }) async {
    final offline = items.any((i) => i.isFlight) ? !(await ConnectivityService.instance.isOnline()) : false;
    if (!context.mounted) return;
    final result = await showDialog<(String, ItineraryItem)>(
      context: context,
      builder: (_) => PlanGroupDialog(trip: trip, day: day, items: items, offline: offline),
    );
    if (result != null && context.mounted) {
      await PlanDetailsDialog.runAction(context, trip, day, result.$2, result.$1);
    }
  }

  @override
  State<PlanGroupDialog> createState() => _PlanGroupDialogState();
}

class _PlanGroupDialogState extends State<PlanGroupDialog> {
  final _controller = PageController();
  int _page = 0;
  // Measured natural height of each page's content, so the dialog sizes to the
  // current plan instead of a fixed slab of whitespace.
  final Map<int, double> _heights = {};

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.items;
    final maxH = MediaQuery.of(context).size.height * 0.7;
    final measured = _heights[_page];
    // Height = current page's content, capped; a sensible default until measured.
    final pageH = (measured ?? maxH * 0.5).clamp(0.0, maxH);
    return Dialog(
      backgroundColor: AppColors.surfaceHigh,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: pageH,
            child: PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: items.length,
              itemBuilder: (_, i) => SingleChildScrollView(
                child: _MeasureSize(
                  onChange: (s) {
                    if (_heights[i] == s.height) return;
                    setState(() => _heights[i] = s.height);
                  },
                  child: PlanDetailBody(
                    trip: widget.trip,
                    day: widget.day,
                    item: items[i],
                    offline: widget.offline,
                    onEdit: () => Navigator.pop(context, ('edit', items[i])),
                    onDelete: () => Navigator.pop(context, ('delete', items[i])),
                  ),
                ),
              ),
            ),
          ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < items.length; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page ? AppColors.accent : Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
  }
}

/// The scrollable body of a single plan's read-only details. [onEdit] /
/// [onDelete] fire when the footer buttons are tapped.
class PlanDetailBody extends StatelessWidget {
  final Trip trip;
  final DateTime day;
  final ItineraryItem item;
  final bool offline;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const PlanDetailBody({
    super.key,
    required this.trip,
    required this.day,
    required this.item,
    required this.onEdit,
    required this.onDelete,
    this.offline = false,
  });

  String get _rangeLabel {
    if (item.start == null) return 'Anytime';
    final r = item.displayTimeRangeLabel(day);
    if (r.isNotEmpty) return r;
    return timeLabel(item.startMinutes!);
  }

  @override
  Widget build(BuildContext context) {
    final s = styleOf(item.category);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.isFlight) ...[
            // Flighty-style boarding-pass view for flights.
            FlightCard(item: item, day: day, offline: offline),
            const SizedBox(height: 14),
            _row(Icons.account_balance_wallet_rounded,
                item.cost > 0 ? money(item.cost, trip.currency) : 'Free'),
          ] else ...[
            // Selected category pill only.
            _Pill(style: s),
            const SizedBox(height: 14),
            Text(item.title, style: AppText.display(22)),
            const SizedBox(height: 8),
            _row(Icons.schedule_rounded, _rangeLabel, mono: true),
            if (item.hasLocation) ...[
              const SizedBox(height: 8),
              _row(Icons.place_rounded, item.locationLabel),
            ],
            const SizedBox(height: 8),
            _row(Icons.account_balance_wallet_rounded,
                item.cost > 0 ? money(item.cost, trip.currency) : 'Free'),
          ],
          const SizedBox(height: 16),
          Text('NOTES', style: AppText.label(10)),
          const SizedBox(height: 6),
          Text(
            item.notes.trim().isNotEmpty ? item.notes.trim() : 'No notes',
            style: AppText.body(14,
                color: item.notes.trim().isNotEmpty ? Colors.white : AppColors.textMuted),
          ),
          if (item.attachments.isNotEmpty) ...[
            const SizedBox(height: 14),
            _row(Icons.attach_file_rounded,
                '${item.attachments.length} document${item.attachments.length == 1 ? '' : 's'}',
                color: AppColors.accent),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              GestureDetector(
                onTap: onEdit,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: AppColors.accentGradient,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.edit_rounded, size: 16, color: Colors.black),
                      const SizedBox(width: 6),
                      Text('Edit', style: AppText.body(14, color: Colors.black, weight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.warning),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String text, {Color? color, bool mono = false}) {
    return Row(
      children: [
        Icon(icon, size: 15, color: color ?? AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            // Time uses the timeline's mono label face; other rows use body.
            style: mono
                ? AppText.label(12, color: color ?? AppColors.textSecondary, tracking: 0.2)
                : AppText.body(14, color: color ?? AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

/// Reports its child's laid-out size after each frame — used to size the
/// group dialog to the current page's content.
class _MeasureSize extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onChange;
  const _MeasureSize({required this.child, required this.onChange});

  @override
  State<_MeasureSize> createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<_MeasureSize> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final size = _key.currentContext?.size;
      if (size != null) widget.onChange(size);
    });
    return Container(key: _key, child: widget.child);
  }
}

class _Pill extends StatelessWidget {
  final CategoryStyle style;
  const _Pill({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 13, color: style.color),
          const SizedBox(width: 6),
          Text(style.label.toUpperCase(), style: AppText.label(9, color: style.color, tracking: 1)),
        ],
      ),
    );
  }
}
