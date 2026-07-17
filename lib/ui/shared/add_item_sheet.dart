import 'dart:async';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import '../../controllers/trip_controller.dart';
import '../../models/attachment.dart';
import '../../models/category.dart';
import '../../models/itinerary_item.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../services/attachment_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/flight_lookup_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'money_field.dart';
import 'place_search_field.dart';
import 'sheet_scaffold.dart';

/// How flight details are entered: look them up from a code, or type manually.
enum _FlightEntry { code, manual }

/// Create or edit an itinerary item for a given [day] within [trip]. Viewing a
/// plan read-only lives in PlanDetailsDialog; this sheet is create/edit only.
class AddItemSheet extends StatefulWidget {
  final Trip trip;
  final DateTime day;
  final ItineraryItem? existing;
  final bool startEditing;

  const AddItemSheet({
    super.key,
    required this.trip,
    required this.day,
    this.existing,
    this.startEditing = false,
  });

  static Future<void> show(
    BuildContext context, {
    required Trip trip,
    required DateTime day,
    ItineraryItem? existing,
    bool startEditing = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddItemSheet(
        trip: trip,
        day: day,
        existing: existing,
        startEditing: startEditing,
      ),
    );
  }

  @override
  State<AddItemSheet> createState() => _AddItemSheetState();
}

class _AddItemSheetState extends State<AddItemSheet> {
  late final TextEditingController _title;
  Place? _location;
  late final TextEditingController _notes;
  late final TextEditingController _cost;
  late final List<Attachment> _attachments;
  late PlanCategory _category;
  int? _start;
  int? _end;
  int _endDayOffset = 0;
  int _initialEndDayOffset = 0;
  int? _reminderLead;

  // Flight fields (used when _category == flight). _location is the "From".
  late final TextEditingController _flightCode;
  late final TextEditingController _airlineName;
  Place? _arrivalLocation;
  late final TextEditingController _departureCode;
  late final TextEditingController _arrivalCode;

  _FlightEntry _flightEntry = _FlightEntry.code;
  bool _online = true;
  StreamSubscription<bool>? _connSub;

  /// Reminder lead-time options (minutes before start). Null = off.
  static const _reminderOptions = <int?, String>{
    null: 'Off',
    15: '15 min',
    30: '30 min',
    60: '1 hr',
    1440: '1 day',
  };

  /// This sheet is always editable (read-only viewing lives in
  /// PlanDetailsDialog). Kept as a field so the existing enable/disable guards
  /// on inputs read naturally.
  final bool _editing = true;

  /// True while a picked document is being copied into app storage.
  bool _uploading = false;

  /// True while an AviationStack flight lookup is in flight.
  bool _lookingUp = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title ?? '');
    _location = e?.location;
    _notes = TextEditingController(text: e?.notes ?? '');
    _cost = TextEditingController(text: e != null ? moneyInput(e.cost) : '');
    _attachments = e != null ? List.of(e.attachments) : [];
    _category = e?.category ?? PlanCategory.activity;
    _start = e?.startMinutes;
    _end = e?.endMinutes;
    _endDayOffset = e != null && e.start != null && e.end != null
        ? DateTime(e.end!.year, e.end!.month, e.end!.day)
              .difference(
                DateTime(widget.day.year, widget.day.month, widget.day.day),
              )
              .inDays
        : 0;
    _initialEndDayOffset = _endDayOffset;
    _reminderLead = e?.reminderLeadMinutes;
    _flightCode = TextEditingController(text: e?.flightCode ?? '');
    _airlineName = TextEditingController(text: e?.airlineName ?? '');
    _arrivalLocation = e?.arrivalLocation;
    _departureCode = TextEditingController(text: e?.departureCode ?? '');
    _arrivalCode = TextEditingController(text: e?.arrivalCode ?? '');
    // Re-evaluate the save button as the text fields change.
    _title.addListener(_markChanged);
    _notes.addListener(_markChanged);
    _cost.addListener(_markChanged);
    _flightCode.addListener(_markChanged);
    _airlineName.addListener(_markChanged);
    _departureCode.addListener(_markChanged);
    _arrivalCode.addListener(_markChanged);
    // Track connectivity: the flight-code lookup needs the network, so when
    // offline we steer to manual entry.
    _connSub = ConnectivityService.instance.onlineStream.listen(_setOnline);
    ConnectivityService.instance.isOnline().then(_setOnline);
  }

  void _setOnline(bool online) {
    if (!mounted) return;
    setState(() {
      _online = online;
    });
  }

  void _markChanged() => setState(() {});

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _cost.dispose();
    _flightCode.dispose();
    _airlineName.dispose();
    _departureCode.dispose();
    _arrivalCode.dispose();
    _connSub?.cancel();
    super.dispose();
  }

  bool get _isFlight => _category == PlanCategory.flight;

  /// True when the form differs from the stored item (always true for a new
  /// item, so the save button enables as soon as it's valid).
  bool get _dirty {
    final e = widget.existing;
    if (e == null) return true;
    return _title.text.trim() != e.title ||
        _location != e.location ||
        _notes.text.trim() != e.notes ||
        parseMoney(_cost.text) != e.cost ||
        _category != e.category ||
        _start != e.startMinutes ||
        _end != e.endMinutes ||
        _endDayOffset != _initialEndDayOffset ||
        _reminderLead != e.reminderLeadMinutes ||
        _flightCode.text.trim() != (e.flightCode ?? '') ||
        _airlineName.text.trim() != (e.airlineName ?? '') ||
        _arrivalLocation != e.arrivalLocation ||
        _departureCode.text.trim() != (e.departureCode ?? '') ||
        _arrivalCode.text.trim() != (e.arrivalCode ?? '') ||
        !_attachmentsEqual(_attachments, e.attachments);
  }

  bool _attachmentsEqual(List<Attachment> a, List<Attachment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
  }

  Future<void> _pickTime(bool isStart) async {
    final current = isStart ? _start : _end;
    final picked = await showTimePicker(
      context: context,
      initialTime: current != null
          ? TimeOfDay(hour: current ~/ 60, minute: current % 60)
          : const TimeOfDay(hour: 9, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.dark(
            primary: AppColors.accent,
            onPrimary: Colors.black,
            surface: AppColors.surfaceHigh,
            onSurface: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        final mins = picked.hour * 60 + picked.minute;
        if (isStart) {
          _start = mins;
          if (_end != null && _end! < mins) {
            _endDayOffset = 1;
          }
        } else {
          _end = mins;
          if (_start != null) {
            _endDayOffset = _end! < _start! ? 1 : _endDayOffset;
          }
        }
      });
    }
  }

  bool get _valid => _title.text.trim().isNotEmpty;

  String? _nn(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (await _commit() && mounted) Navigator.pop(context);
  }

  /// Writes the form into the model (add or update). Returns false if invalid
  /// or the overlap prompt was cancelled. Does not close the sheet.
  Future<bool> _commit() async {
    if (!_valid) return false;
    final cost = parseMoney(_cost.text);
    if (await _hasOverlapConfirmed() == false) return false;
    final e = widget.existing;
    if (e == null) {
      final endDate = _end != null
          ? DateTime(
              widget.day.add(Duration(days: _endDayOffset)).year,
              widget.day.add(Duration(days: _endDayOffset)).month,
              widget.day.add(Duration(days: _endDayOffset)).day,
              _end! ~/ 60,
              _end! % 60,
            )
          : null;
      await TripController.instance.addItem(
        widget.trip.id,
        (id) => ItineraryItem(
          id: id,
          title: _title.text.trim(),
          location: _location,
          notes: _notes.text.trim(),
          category: _category,
          day: widget.day,
          start: _start != null
              ? DateTime(
                  widget.day.year,
                  widget.day.month,
                  widget.day.day,
                  _start! ~/ 60,
                  _start! % 60,
                )
              : null,
          end: endDate,
          cost: cost,
          attachments: _attachments,
          reminderLeadMinutes: _start != null ? _reminderLead : null,
          flightCode: _isFlight ? _nn(_flightCode) : null,
          airlineName: _isFlight ? _nn(_airlineName) : null,
          arrivalLocation: _isFlight ? _arrivalLocation : null,
          departureCode: _isFlight ? _nn(_departureCode) : null,
          arrivalCode: _isFlight ? _nn(_arrivalCode) : null,
        ),
      );
    } else {
      e.title = _title.text.trim();
      e.location = _location;
      e.notes = _notes.text.trim();
      e.category = _category;
      e.start = _start != null
          ? DateTime(
              widget.day.year,
              widget.day.month,
              widget.day.day,
              _start! ~/ 60,
              _start! % 60,
            )
          : null;
      if (_end != null) {
        final endDay = widget.day.add(Duration(days: _endDayOffset));
        e.end = DateTime(
          endDay.year,
          endDay.month,
          endDay.day,
          _end! ~/ 60,
          _end! % 60,
        );
      } else {
        e.end = null;
      }
      e.cost = cost;
      e.attachments = _attachments;
      e.reminderLeadMinutes = _start != null ? _reminderLead : null;
      e.flightCode = _isFlight ? _nn(_flightCode) : null;
      e.airlineName = _isFlight ? _nn(_airlineName) : null;
      e.arrivalLocation = _isFlight ? _arrivalLocation : null;
      e.departureCode = _isFlight ? _nn(_departureCode) : null;
      e.arrivalCode = _isFlight ? _nn(_arrivalCode) : null;
      await TripController.instance.updateItem(widget.trip.id);
    }
    return true;
  }

  Future<bool> _hasOverlapConfirmed() async {
    final itemRange = _buildCandidateItemRange();
    if (itemRange == null) return true;
    final overlaps = widget.trip.items.where((existing) {
      if (widget.existing != null && existing.id == widget.existing!.id) {
        return false;
      }
      if (existing.start == null || existing.end == null) return false;
      return itemRange.start.isBefore(existing.end!) &&
          existing.start!.isBefore(itemRange.end);
    }).toList();
    if (overlaps.isEmpty) return true;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Plan overlap detected'),
            content: const Text(
              'This item overlaps another plan. Save anyway?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Save anyway'),
              ),
            ],
          ),
        ) ??
        false;
  }

  _CandidateItemRange? _buildCandidateItemRange() {
    if (_start == null || _end == null) return null;
    final startDate = DateTime(
      widget.day.year,
      widget.day.month,
      widget.day.day,
      _start! ~/ 60,
      _start! % 60,
    );
    final endDate = DateTime(
      widget.day.add(Duration(days: _endDayOffset)).year,
      widget.day.add(Duration(days: _endDayOffset)).month,
      widget.day.add(Duration(days: _endDayOffset)).day,
      _end! ~/ 60,
      _end! % 60,
    );
    return _CandidateItemRange(start: startDate, end: endDate);
  }

  Future<void> _confirmDelete() async {
    final e = widget.existing;
    if (e == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Delete plan?', style: AppText.display(20)),
        content: Text(
          '“${e.title}” will be removed from this day.',
          style: AppText.body(14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: AppText.body(14, color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Delete',
              style: AppText.body(14, color: AppColors.warning),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    // Clean up any attachment files belonging to this plan.
    await AttachmentService.instance.deleteAll(e.attachments);
    await TripController.instance.deleteItem(widget.trip.id, e.id);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isNew = widget.existing == null;
    final showDone = !isNew && widget.startEditing;
    return SheetScaffold(
      title: isNew ? 'Add Plan' : 'Edit Plan',
      showSave: true,
      onSave: (_valid && (isNew || _dirty)) ? _save : null,
      onDone: showDone ? (_dirty ? _save : () => Navigator.pop(context)) : null,
      doneActive: _dirty,
      onDelete: !isNew ? _confirmDelete : null,
      children: [
        Text(
          fullDate(widget.day),
          style: AppText.label(11, color: AppColors.accent),
        ),
        const SizedBox(height: 16),
        _field('What', _title, 'Visit Senso-ji Temple'),
        const SizedBox(height: 18),
        Text('CATEGORY', style: AppText.label(10)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: PlanCategory.values.map((c) {
            final s = styleOf(c);
            final selected = c == _category;
            return GestureDetector(
              onTap: _editing ? () => setState(() => _category = c) : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: selected
                      ? s.color.withValues(alpha: 0.18)
                      : AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: selected
                        ? s.color
                        : Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      s.icon,
                      size: 15,
                      color: selected ? s.color : AppColors.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      s.label,
                      style: AppText.body(
                        13,
                        color: selected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        // Non-flight plans set times here. Flights set them in the flight
        // section: auto-filled by the code lookup, or under Manual entry.
        if (!_isFlight) ...[
          _timeRow(),
          if (_end != null) ...[
            const SizedBox(height: 10),
            _endDayOffsetControl(),
          ],
          const SizedBox(height: 18),
        ],
        _reminderControl(),
        const SizedBox(height: 18),
        if (_isFlight) ...[
          _timeRow(),
          if (_end != null) ...[
            const SizedBox(height: 10),
            _endDayOffsetControl(),
          ],
          const SizedBox(height: 18),
          _flightModeToggle(),
          const SizedBox(height: 16),
          if (_flightEntry == _FlightEntry.code) ...[
            _flightNumberField(),
            if (_hasFlightResult) ...[
              const SizedBox(height: 14),
              _flightResultCard(),
            ],
          ] else ...[
            _field('Airline', _airlineName, 'e.g. Delta Air Lines'),
            const SizedBox(height: 18),
            _field('Flight code', _flightCode, 'e.g. DL299'),
            const SizedBox(height: 18),
            _flightEndpoint(
              'FROM',
              _location,
              _departureCode,
              'SFO',
              (p) => setState(() => _location = p),
            ),
            const SizedBox(height: 14),
            _flightEndpoint(
              'TO',
              _arrivalLocation,
              _arrivalCode,
              'HND',
              (p) => setState(() => _arrivalLocation = p),
            ),
          ],
        ] else ...[
          Text('LOCATION', style: AppText.label(10)),
          const SizedBox(height: 8),
          if (_editing)
            PlaceSearchField(
              initialValue: _location,
              hint: 'Search city — e.g. Asakusa',
              onSelected: (place) => setState(() => _location = place),
            )
          else
            _readOnlyBox(
              icon: Icons.location_on_outlined,
              text: _location?.label ?? 'No location',
              muted: _location == null,
            ),
        ],
        const SizedBox(height: 18),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('COST', style: AppText.label(10)),
            const SizedBox(height: 8),
            MoneyField(
              controller: _cost,
              symbol: symbolFor(widget.trip.currency),
              readOnly: !_editing,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _field(
          'Notes',
          _notes,
          'Bring camera, opens at 6am',
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 18),
        Text('DOCUMENTS', style: AppText.label(10)),
        const SizedBox(height: 10),
        // Uploaded documents first, so a newly added one is immediately visible.
        for (final attachment in _attachments) _attachmentTile(attachment),
        if (_uploading) _uploadingTile(),
        if (_attachments.isEmpty && !_uploading && !_editing)
          _readOnlyBox(
            icon: Icons.attach_file_rounded,
            text: 'No documents',
            muted: true,
          ),
        // Add button sits below the list.
        if (_editing) ...[
          if (_attachments.isNotEmpty || _uploading) const SizedBox(height: 6),
          GestureDetector(
            onTap: _uploading ? null : _pickAttachment,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.attach_file_rounded,
                    size: 16,
                    color: _uploading ? AppColors.textMuted : AppColors.accent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Add document',
                    style: AppText.body(
                      14,
                      color: _uploading
                          ? AppColors.textMuted
                          : AppColors.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _uploadingTile() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Saving document…',
              style: AppText.body(14, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _readOnlyBox({
    required IconData icon,
    required String text,
    bool muted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppText.body(
                14,
                color: muted ? AppColors.textMuted : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController c,
    String hint, {
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.label(10)),
        const SizedBox(height: 8),
        TextField(
          controller: c,
          maxLines: maxLines,
          readOnly: !_editing,
          textCapitalization: textCapitalization,
          // In view mode the field can't be focused, so it never shows the
          // accent focus border or a cursor.
          canRequestFocus: _editing,
          style: AppText.body(15),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: AppText.body(15, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: _b(Colors.white.withValues(alpha: 0.06)),
            enabledBorder: _b(Colors.white.withValues(alpha: 0.06)),
            focusedBorder: _b(
              _editing
                  ? AppColors.accent
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
        ),
      ],
    );
  }

  /// Start/end time pickers. Labelled Departs/Arrives for flights.
  Widget _timeRow() {
    return Row(
      children: [
        Expanded(
          child: _timeButton(
            _isFlight ? 'Departs' : 'Starts',
            _start,
            _editing ? () => _pickTime(true) : null,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _timeButton(
            _isFlight ? 'Arrives' : 'Ends',
            _end,
            _editing ? () => _pickTime(false) : null,
          ),
        ),
      ],
    );
  }

  bool get _hasFlightResult =>
      _airlineName.text.trim().isNotEmpty ||
      _departureCode.text.trim().isNotEmpty ||
      _arrivalCode.text.trim().isNotEmpty ||
      _location != null ||
      _arrivalLocation != null;

  /// Segmented control: look a flight up by code, or type its details manually.
  /// The code option is disabled (shown greyed) when offline.
  Widget _flightModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: _modeSeg('Flight code', _FlightEntry.code, enabled: true),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _modeSeg('Manual', _FlightEntry.manual, enabled: true),
            ),
          ],
        ),
      ],
    );
  }

  Widget _modeSeg(String label, _FlightEntry mode, {required bool enabled}) {
    final selected = _flightEntry == mode;
    return GestureDetector(
      onTap: enabled ? () => setState(() => _flightEntry = mode) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.18)
              : AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: selected
                ? AppColors.accent
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Text(
          label,
          style: AppText.body(
            13,
            color: selected
                ? Colors.white
                : (enabled ? AppColors.textSecondary : AppColors.textMuted),
          ),
        ),
      ),
    );
  }

  /// Read-only summary shown after a code lookup (or for a saved flight):
  /// airline, route, and times. Editing happens by switching to Manual.
  Widget _flightResultCard() {
    final c = styleOf(PlanCategory.flight).color;
    String big(TextEditingController code, Place? place) {
      final v = code.text.trim();
      if (v.isNotEmpty) return v.toUpperCase();
      return place?.label.split(',').first.trim() ?? '—';
    }

    final depT = _start != null ? timeLabel(_start!) : '—';
    final arrT = _end != null ? timeLabel(_end!) : '—';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.flight_rounded, size: 16, color: c),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _airlineName.text.trim().isNotEmpty
                      ? _airlineName.text.trim()
                      : 'Flight',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(14, weight: FontWeight.w600),
                ),
              ),
              if (_flightCode.text.trim().isNotEmpty)
                Text(
                  _flightCode.text.trim().toUpperCase(),
                  style: AppText.label(11, color: c),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _resultEndpoint(
                big(_departureCode, _location),
                depT,
                CrossAxisAlignment.start,
              ),
              Expanded(
                child: Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ),
              _resultEndpoint(
                big(_arrivalCode, _arrivalLocation),
                arrT,
                CrossAxisAlignment.end,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultEndpoint(String code, String time, CrossAxisAlignment align) {
    return Column(
      crossAxisAlignment: align,
      children: [
        Text(code, style: AppText.display(22)),
        const SizedBox(height: 2),
        Text(time, style: AppText.label(11, color: AppColors.textSecondary)),
      ],
    );
  }

  /// Flight-number field with an "Auto-fill" action that looks the flight up on
  /// AviationStack and populates the route, airport codes, and times.
  Widget _flightNumberField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('FLIGHT', style: AppText.label(10)),
            const Spacer(),
            GestureDetector(
              onTap: (_lookingUp || !_online) ? null : _lookupFlight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_lookingUp)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accent,
                      ),
                    )
                  else
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 14,
                      color: _online ? AppColors.accent : AppColors.textMuted,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    _lookingUp ? 'Looking up…' : 'Auto-fill',
                    style: AppText.label(
                      11,
                      color: _online ? AppColors.accent : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _flightCode,
          readOnly: !_editing,
          textCapitalization: TextCapitalization.characters,
          style: AppText.body(15),
          cursorColor: AppColors.accent,
          onSubmitted: (_) => _lookupFlight(),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'e.g. DL299',
            hintStyle: AppText.body(15, color: AppColors.textMuted),
            filled: true,
            fillColor: AppColors.surfaceLow,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: _b(Colors.white.withValues(alpha: 0.06)),
            enabledBorder: _b(Colors.white.withValues(alpha: 0.06)),
            focusedBorder: _b(AppColors.accent),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _online
              ? 'Auto-fill pulls live flight data — best for flights operating today. Otherwise use Manual.'
              : 'Offline — connect to look up a flight, or switch to Manual.',
          style: AppText.body(11, color: AppColors.textMuted),
        ),
      ],
    );
  }

  Future<void> _lookupFlight() async {
    final code = _flightCode.text.trim();
    if (code.isEmpty) {
      _snack('Enter a flight number first');
      return;
    }
    setState(() => _lookingUp = true);
    // Note: the free AviationStack tier is live-only (a flight_date filter is a
    // paid feature that errors out), so we don't pass the trip day — we look up
    // the flight as it operates today.
    final info = await FlightLookupService.instance.lookup(code);
    if (!mounted) return;
    if (info == null) {
      setState(() => _lookingUp = false);
      _snack('No live data for $code today — enter the details manually');
      return;
    }
    setState(() {
      _lookingUp = false;
      _flightCode.text = info.flightIata;
      if (info.airlineName != null) _airlineName.text = info.airlineName!;
      if (info.departureCode != null) _departureCode.text = info.departureCode!;
      if (info.arrivalCode != null) _arrivalCode.text = info.arrivalCode!;
      if (info.departure != null) _location = info.departure;
      if (info.arrival != null) _arrivalLocation = info.arrival;
      if (info.departureMinutes != null) _start = info.departureMinutes;
      if (info.arrivalMinutes != null) _end = info.arrivalMinutes;
      _endDayOffset = info.endDayOffset;
      if (_title.text.trim().isEmpty) {
        _title.text = info.airlineName != null
            ? '${info.airlineName} ${info.flightIata}'
            : 'Flight ${info.flightIata}';
      }
    });
    _snack('Filled in ${info.flightIata}');
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// A flight endpoint row: a city search field plus a small IATA-code field.
  Widget _flightEndpoint(
    String label,
    Place? place,
    TextEditingController code,
    String codeHint,
    ValueChanged<Place?> onPlace,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppText.label(10)),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: PlaceSearchField(
                initialValue: place,
                hint: 'Search city',
                onSelected: onPlace,
                allowFreeText: true,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 1,
              child: TextField(
                controller: code,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 4,
                style: AppText.body(15),
                cursorColor: AppColors.accent,
                decoration: InputDecoration(
                  isDense: true,
                  counterText: '',
                  hintText: codeHint,
                  hintStyle: AppText.body(15, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLow,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 14,
                  ),
                  border: _b(Colors.white.withValues(alpha: 0.06)),
                  enabledBorder: _b(Colors.white.withValues(alpha: 0.06)),
                  focusedBorder: _b(AppColors.accent),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reminderControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('REMINDER', style: AppText.label(10)),
        const SizedBox(height: 8),
        if (_start == null)
          Text(
            'Set a start time to enable a reminder.',
            style: AppText.body(13, color: AppColors.textMuted),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _reminderOptions.entries.map((entry) {
              final selected = _reminderLead == entry.key;
              return GestureDetector(
                onTap: _editing
                    ? () => setState(() => _reminderLead = entry.key)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.accent.withValues(alpha: 0.18)
                        : AppColors.surfaceLow,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: selected
                          ? AppColors.accent
                          : Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Text(
                    entry.value,
                    style: AppText.body(
                      13,
                      color: selected ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _endDayOffsetControl() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ENDS ON', style: AppText.label(10)),
        const SizedBox(height: 10),
        Row(
          children: [
            GestureDetector(
              onTap: (_editing && _endDayOffset > 0)
                  ? () => setState(() => _endDayOffset--)
                  : null,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: _endDayOffset > 0
                      ? AppColors.surfaceLow
                      : AppColors.surfaceLow.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  Icons.remove,
                  size: 18,
                  color: _endDayOffset > 0 ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Text(
                  _endDayOffset == 0
                      ? 'Same day'
                      : _endDayOffset == 1
                      ? 'Next day'
                      : '+$_endDayOffset days',
                  style: AppText.body(14, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _editing ? () => setState(() => _endDayOffset++) : null,
              child: Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.surfaceLow,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: _editing ? Colors.white : AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  OutlineInputBorder _b(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c),
  );

  Widget _attachmentTile(Attachment attachment) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => _openAttachment(attachment),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  attachment.fileName,
                  style: AppText.body(14, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_editing) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () async {
                    await _removeAttachment(attachment);
                  },
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAttachment() async {
    // file_selector uses the platform document picker (UIDocumentPicker on
    // iOS) — no photo-library/camera permissions required.
    final file = await openFile();
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final id = '${DateTime.now().microsecondsSinceEpoch}_${widget.trip.id}';
      // importFile copies the bytes into the app's documents directory, so the
      // attachment survives even if the original file is later deleted.
      final attachment = await AttachmentService.instance.importFile(
        id: id,
        sourcePath: file.path,
        displayName: file.name,
      );
      if (!mounted) return;
      setState(() => _attachments.add(attachment));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save that document')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openAttachment(Attachment attachment) async {
    try {
      final file = await AttachmentService.instance.fileFor(attachment);
      await OpenFilex.open(file.path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to open ${attachment.fileName}')),
      );
    }
  }

  Future<void> _removeAttachment(Attachment attachment) async {
    await AttachmentService.instance.delete(attachment);
    setState(() {
      _attachments.removeWhere((a) => a.id == attachment.id);
    });
  }

  Widget _timeButton(String label, int? value, VoidCallback? onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.label(10)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: onTap != null ? AppColors.accent : AppColors.textMuted,
                ),
                const SizedBox(width: 10),
                Text(
                  value != null ? timeLabel(value) : 'Anytime',
                  style: AppText.body(
                    14,
                    color: value != null ? Colors.white : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CandidateItemRange {
  final DateTime start;
  final DateTime end;

  _CandidateItemRange({required this.start, required this.end});
}
