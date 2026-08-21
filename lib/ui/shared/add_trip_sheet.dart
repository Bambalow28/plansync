import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../data/suggested_places.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'date_range_dialog.dart';
import 'money_field.dart';
import 'place_search_field.dart';

/// Full page to create a new trip or edit an existing one.
class AddTripSheet extends StatefulWidget {
  final Trip? existing;

  /// Pre-fills the destination for a new trip started from a place the user
  /// already picked. Ignored when editing an existing trip.
  final Place? initialDestination;

  /// A trending plan the user chose to start with — pre-fills the budget and,
  /// once dates are picked, fills the trip's first days from its template.
  /// Ignored when editing an existing trip.
  final SuggestedPlace? planSource;

  const AddTripSheet({
    super.key,
    this.existing,
    this.initialDestination,
    this.planSource,
  });

  static Future<void> show(
    BuildContext context, {
    Trip? existing,
    Place? initialDestination,
    SuggestedPlace? planSource,
  }) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddTripSheet(
          existing: existing,
          initialDestination: initialDestination,
          planSource: planSource,
        ),
      ),
    );
  }

  @override
  State<AddTripSheet> createState() => _AddTripSheetState();
}

class _AddTripSheetState extends State<AddTripSheet> {
  late final TextEditingController _name;
  Place? _destination;
  late final TextEditingController _budget;
  DateTime? _start;
  DateTime? _end;
  late String _currency;

  static const _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'MXN'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final plan = widget.planSource;
    // A trip started from a chosen place (or a plan) gets that city as its
    // working name — the user can still edit it before saving.
    _name = TextEditingController(
      text: e?.name ?? widget.initialDestination?.city ?? plan?.city ?? '',
    );
    _destination = e?.destination ?? widget.initialDestination ?? plan?.toPlace();
    _budget = TextEditingController(
      text: e != null
          ? moneyInput(e.budget)
          : (plan != null ? moneyInput(plan.planBudget) : ''),
    );
    _start = e?.startDate;
    _end = e?.endDate;
    _currency = e?.currency ?? 'USD';
    // Re-evaluate the Save button as the text fields change.
    _name.addListener(_changed);
    _budget.addListener(_changed);
  }

  void _changed() => setState(() {});

  /// True when the form differs from the stored trip (always true for a new
  /// trip, so Save enables as soon as it's valid).
  bool get _dirty {
    final e = widget.existing;
    if (e == null) return true;
    return _name.text.trim() != e.name ||
        _destination != e.destination ||
        _start != e.startDate ||
        _end != e.endDate ||
        parseMoney(_budget.text) != e.budget ||
        _currency != e.currency;
  }

  @override
  void dispose() {
    _name.dispose();
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

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _destination != null &&
      _start != null &&
      _end != null &&
      !_start!.isAfter(_end!);

  Future<void> _save() async {
    if (_destination == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a destination.')),
      );
      return;
    }
    if (_start == null || _end == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please choose start and end dates.')),
      );
      return;
    }
    if (_start!.isAfter(_end!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be equal to or after the start date.'),
        ),
      );
      return;
    }
    if (!_valid) return;
    final budget = parseMoney(_budget.text);
    final e = widget.existing;
    if (e == null) {
      final trip = await TripController.instance.addTrip(
        name: _name.text.trim(),
        destination: _destination,
        startDate: _start!,
        endDate: _end!,
        budget: budget,
        currency: _currency,
      );
      final plan = widget.planSource;
      if (plan != null) {
        await TripController.instance.addItems(
          trip.id,
          plan.planItinerary(trip.startDate, trip.dayCount),
        );
      }
    } else {
      e.name = _name.text.trim();
      e.destination = _destination;
      e.startDate = _start!;
      e.endDate = _end!;
      e.budget = budget;
      e.currency = _currency;
      await TripController.instance.updateTrip(e);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _valid && (widget.existing == null || _dirty);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          widget.existing == null ? 'New Trip' : 'Edit Trip',
          style: AppText.display(20),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(
                      label: 'Trip name',
                      controller: _name,
                      hint: 'Japan 2026',
                    ),
        const SizedBox(height: 16),
        Text('DESTINATION', style: AppText.label(10)),
        const SizedBox(height: 8),
        PlaceSearchField(
          initialValue: _destination,
          hint: 'Search city — e.g. Tokyo',
          onSelected: (place) => setState(() => _destination = place),
        ),
        const SizedBox(height: 16),
        _DatesRow(start: _start, end: _end, onTap: _pickDates),
        const SizedBox(height: 16),
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
                  MoneyField(controller: _budget, symbol: symbolFor(_currency)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _CurrencyDropdown(
                value: _currency,
                onChanged: (v) => setState(() => _currency = v),
              ),
            ),
          ],
        ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                4,
                24,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              child: GestureDetector(
                onTap: canSave ? _save : null,
                child: Opacity(
                  opacity: canSave ? 1 : 0.4,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      widget.existing == null ? 'Save' : 'Save changes',
                      style: AppText.body(
                        16,
                        color: Colors.black,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: AppText.label(10)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
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
            border: _border(Colors.white.withValues(alpha: 0.06)),
            enabledBorder: _border(Colors.white.withValues(alpha: 0.06)),
            focusedBorder: _border(AppColors.accent),
          ),
        ),
      ],
    );
  }

  OutlineInputBorder _border(Color c) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: c),
  );
}

class _CurrencyDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _CurrencyDropdown({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CURRENCY', style: AppText.label(10)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: AppColors.surfaceLow,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: AppColors.surfaceHigh,
              style: AppText.body(15),
              icon: Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
              items: _AddTripSheetState._currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => onChanged(v ?? value),
            ),
          ),
        ),
      ],
    );
  }
}

class _DatesRow extends StatelessWidget {
  final DateTime? start;
  final DateTime? end;
  final VoidCallback onTap;
  const _DatesRow({
    required this.start,
    required this.end,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('DATES', style: AppText.label(10)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
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
                    start != null && end != null
                        ? shortRange(start!, end!)
                        : 'Add trip dates',
                    style: AppText.body(
                      15,
                      color: start != null && end != null
                          ? AppColors.textPrimary
                          : AppColors.textMuted,
                    ),
                  ),
                ),
                if (start != null && end != null) ...[
                  Text(
                    '${end!.difference(start!).inDays + 1} days',
                    style: AppText.label(11, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
