import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/category.dart';
import '../../models/itinerary_item.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../services/ai_itinerary_service.dart';
import '../../services/connectivity_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../trip/trip_detail_screen.dart';
import '../trip/trip_review_screen.dart';
import '../../services/settings_service.dart';
import 'date_range_dialog.dart';
import 'add_trip_sheet.dart' show CurrencyDropdown;
import 'hotel_address_field.dart';
import 'money_field.dart';
import 'place_search_field.dart';

/// Drafts a trip via [AiItineraryService]: destination, dates, budget and
/// currency in, a day-by-day itinerary out. The step rail plays on a fixed pace
/// (the API isn't streamed) and holds on its last step until the draft lands.
class AiCreateTripScreen extends StatefulWidget {
  /// Pre-fills the destination when the flow was entered from a place the user
  /// already picked (home search bar, suggested-destination carousel).
  final Place? initialDestination;

  /// Pre-fills the budget field (e.g. a trending plan's suggested total).
  final double? initialBudget;

  const AiCreateTripScreen({super.key, this.initialDestination, this.initialBudget});

  @override
  State<AiCreateTripScreen> createState() => _AiCreateTripScreenState();
}

const _kStartLabel = 'Creating your itinerary';
const _kDoneLabel = 'Your itinerary is ready!';

const _kDemoSteps = [
  'Finding things to do',
  'Finding great places to eat',
  'Finding sightseeing spots',
  'Planning local transport',
  'Adding final touches',
];

class _AiCreateTripScreenState extends State<AiCreateTripScreen> {
  Place? _destination;
  DateTime? _start;
  DateTime? _end;
  String _hotelAddress = '';
  late final TextEditingController _budget;
  String _currency = SettingsService.instance.defaultCurrency;
  String? _error;

  bool _generating = false;
  bool _done = false;
  List<String> _progress = const [];
  Trip? _createdTrip;

  bool _online = true;
  StreamSubscription<bool>? _connSub;

  @override
  void initState() {
    super.initState();
    _destination = widget.initialDestination;
    _budget = TextEditingController(text: moneyInput(widget.initialBudget ?? 0));
    // Generation calls Gemini, so gate it the same way the flight-code lookup
    // gates itself elsewhere in the app: online status only.
    _connSub = ConnectivityService.instance.onlineStream.listen(_setOnline);
    ConnectivityService.instance.isOnline().then(_setOnline);
  }

  void _setOnline(bool online) {
    if (!mounted) return;
    setState(() => _online = online);
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final range = await showAppDateRangeDialog(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialStart: _start,
      initialEnd: _end,
    );
    if (range != null) {
      setState(() {
        _start = range.start;
        _end = range.end;
      });
    }
  }

  bool get _canGenerate =>
      _destination != null && _start != null && _end != null && _online;

  Future<void> _generate() async {
    if (_generating) return;
    if (_done) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _createdTrip!.isPast
              ? TripReviewScreen(tripId: _createdTrip!.id)
              : TripDetailScreen(tripId: _createdTrip!.id, showFullTopBar: true),
        ),
      );
      return;
    }
    setState(() {
      _generating = true;
      _done = false;
      _error = null;
      _progress = [_kStartLabel];
    });

    final reveal = () async {
      for (final label in _kDemoSteps) {
        await Future.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
        setState(() => _progress = [..._progress, label]);
      }
    }();

    final hotel = _hotelAddress.trim();
    final budget = parseMoney(_budget.text);
    final List<ItineraryItem Function(String id)> aiItems;
    try {
      aiItems = await AiItineraryService.instance.generate(
        destination: _destination!,
        start: _start!,
        end: _end!,
        budget: budget,
        currency: _currency,
        hotelAddress: hotel.isEmpty ? null : hotel,
      );
    } on AiItineraryException catch (e) {
      if (!mounted) return;
      setState(() {
        _generating = false;
        _error = e.message;
      });
      return;
    }
    await reveal;
    if (!mounted) return;

    final trip = await TripController.instance.addTrip(
      name: _destination!.city,
      destination: _destination,
      startDate: _start!,
      endDate: _end!,
      budget: budget,
      currency: _currency,
    );
    final items = [
      if (hotel.isNotEmpty)
        (String id) => ItineraryItem(
          id: id,
          title: 'Hotel check-in',
          category: PlanCategory.lodging,
          day: _start!,
          location: Place(city: hotel),
        ),
      ...aiItems,
    ];
    if (items.isNotEmpty) {
      await TripController.instance.addItems(trip.id, items);
    }
    // A beat so the last step's fade-in is fully visible before "ready"
    // takes over — otherwise both appear back to back on the same frame.
    await Future.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _generating = false;
      _done = true;
      _createdTrip = trip;
    });
  }

  void _showBlockedBackDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_toy_rounded, size: 40, color: AppColors.accent),
            const SizedBox(height: 12),
            Text(
              'AI is creating your itinerary',
              textAlign: TextAlign.center,
              style: AppText.display(18),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: AppText.body(14, color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final buttonEnabled = !_generating && (_done || _canGenerate);
    return PopScope(
      canPop: !_generating,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _showBlockedBackDialog();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Create with AI', style: AppText.display(20)),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: SingleChildScrollView(
                    child: IgnorePointer(
                      ignoring: _generating,
                      child: Opacity(
                        opacity: _generating ? 0.5 : 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('DESTINATION', style: AppText.label(10)),
                            const SizedBox(height: 8),
                            PlaceSearchField(
                              initialValue: _destination,
                              hint: 'Search city — e.g. Tokyo',
                              // Already filled in from the home screen? Don't
                              // pop the keyboard over the dates step.
                              autofocus: widget.initialDestination == null,
                              onSelected: (place) =>
                                  setState(() => _destination = place),
                            ),
                            const SizedBox(height: 20),
                            Text('DATES', style: AppText.label(10)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: _generating ? null : _pickDates,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 15,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLow,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.06),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 16,
                                      color: AppColors.textMuted,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _start != null && _end != null
                                            ? shortRangeWithYear(_start!, _end!)
                                            : 'Add trip dates',
                                        style: AppText.body(
                                          15,
                                          color: _start != null && _end != null
                                              ? AppColors.textPrimary
                                              : AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('BUDGET', style: AppText.label(10)),
                                      const SizedBox(height: 8),
                                      MoneyField(
                                        controller: _budget,
                                        symbol: symbolFor(_currency),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: CurrencyDropdown(
                                    value: _currency,
                                    onChanged: (v) => setState(() => _currency = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            Text('HOTEL ADDRESS', style: AppText.label(10)),
                            const SizedBox(height: 8),
                            HotelAddressField(
                              initialValue: _hotelAddress,
                              onChanged: (value) => _hotelAddress = value,
                            ),
                          ],
                        ),
                      ),
                    ),
                      ),
                    ),
                    if (_generating || _done)
                      Expanded(child: _StepsRail(labels: _progress, done: _done)),
                  ],
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: AppText.label(11, color: AppColors.warning),
                  ),
                ),
              if (!_online && !_done)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Connect to the internet to generate with AI.',
                    textAlign: TextAlign.center,
                    style: AppText.label(11, color: AppColors.warning),
                  ),
                ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: buttonEnabled ? _generate : null,
                child: Opacity(
                  opacity: buttonEnabled ? 1 : (_generating ? 0.6 : 0.4),
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      _generating
                          ? 'Creating...'
                          : _done
                          ? 'View Trip'
                          : 'Generate itinerary',
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
      ),
      ),
    );
  }
}

/// The step-by-step "thinking" rail: a dot per step joined by a dashed line,
/// each one fading in as it's revealed. The final row ("Your itinerary is
/// ready!")
/// only appears once generation finishes.
class _StepsRail extends StatelessWidget {
  final List<String> labels;
  final bool done;
  const _StepsRail({required this.labels, required this.done});

  @override
  Widget build(BuildContext context) {
    final rows = <String>[
      ...labels,
      if (done) _kDoneLabel,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < rows.length; i++)
            _StepRow(
              key: ValueKey(i),
              label: rows[i],
              // Only the true final ("ready") row stops the line — every
              // other row (even the current last one, mid-generation) keeps
              // drawing its connector down into the invisible filler below,
              // so it reads as "still going" rather than stopping abruptly.
              isLast: done && i == rows.length - 1,
              isFinal: done && i == rows.length - 1,
            ),
          // Invisible spacer — not the rows themselves — soaks up the
          // leftover height so the rail still fills the page without
          // already-revealed rows jumping/resizing as new ones appear.
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }
}

class _StepRow extends StatefulWidget {
  final String label;
  final bool isLast;
  final bool isFinal;
  const _StepRow({
    super.key,
    required this.label,
    required this.isLast,
    required this.isFinal,
  });

  @override
  State<_StepRow> createState() => _StepRowState();
}

class _StepRowState extends State<_StepRow> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const color = AppColors.accent;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final fade = Curves.easeOut.transform(_controller.value);
        final dotScale = Curves.easeOutBack.transform(_controller.value).clamp(0.0, 1.3);
        // The line draws downward a beat behind the fade/dot, so it visibly
        // grows into place instead of just popping in at full length.
        final lineGrow = Curves.easeOutCubic.transform(
          ((_controller.value - 0.15) / 0.85).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: fade,
          child: Transform.translate(
            offset: Offset(0, (1 - fade) * 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Transform.scale(
                        scale: dotScale,
                        child: Container(
                          width: 11,
                          height: 11,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: widget.isFinal ? color : AppColors.background,
                            border: Border.all(color: color, width: 2),
                          ),
                          child: widget.isFinal
                              ? Icon(Icons.check_rounded, size: 8, color: AppColors.background)
                              : null,
                        ),
                      ),
                      if (!widget.isLast)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: ClipRect(
                              clipper: _GrowClipper(lineGrow),
                              child: _DashedLine(color: AppColors.accent.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      widget.label,
                      style: AppText.body(
                        14,
                        color: widget.isFinal ? AppColors.textPrimary : AppColors.textSecondary,
                        weight: widget.isFinal ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Clips a child down to its top [t] fraction — makes the dashed line look
/// like it's drawing downward instead of appearing all at once.
class _GrowClipper extends CustomClipper<Rect> {
  final double t;
  const _GrowClipper(this.t);
  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, 0, size.width, size.height * t.clamp(0.0, 1.0));
  @override
  bool shouldReclip(covariant _GrowClipper old) => old.t != t;
}

/// Dashed vertical connector. Painted (not a [LayoutBuilder]-based [Column] of
/// dashes) because it sits inside an [IntrinsicHeight], which cannot measure a
/// LayoutBuilder.
class _DashedLine extends StatelessWidget {
  final Color color;
  const _DashedLine({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: 2, child: CustomPaint(painter: _DashPainter(color)));
  }
}

class _DashPainter extends CustomPainter {
  final Color color;
  _DashPainter(this.color);

  static const _dash = 4.0, _gap = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    var y = 0.0;
    while (y < size.height) {
      canvas.drawLine(Offset(x, y), Offset(x, math.min(y + _dash, size.height)), paint);
      y += _dash + _gap;
    }
  }

  @override
  bool shouldRepaint(covariant _DashPainter old) => old.color != color;
}
