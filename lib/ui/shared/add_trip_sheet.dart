import 'package:flutter/material.dart';
import '../../controllers/trip_controller.dart';
import '../../models/place.dart';
import '../../models/trip.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'money_field.dart';
import 'place_search_field.dart';
import 'sheet_scaffold.dart';

/// Bottom sheet to create a new trip or edit an existing one.
class AddTripSheet extends StatefulWidget {
  final Trip? existing;
  const AddTripSheet({super.key, this.existing});

  static Future<void> show(BuildContext context, {Trip? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddTripSheet(existing: existing),
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
  late TripCover _cover;

  static const _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'MXN'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _destination = e?.destination;
    _budget = TextEditingController(
      text: e != null ? moneyInput(e.budget) : '',
    );
    _start = e?.startDate;
    _end = e?.endDate;
    _currency = e?.currency ?? 'USD';
    _cover = e?.cover ?? TripCover.teal;
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
        _currency != e.currency ||
        _cover != e.cover;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _start != null && _end != null
          ? DateTimeRange(start: _start!, end: _end!)
          : null,
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
      await TripController.instance.addTrip(
        name: _name.text.trim(),
        destination: _destination,
        startDate: _start!,
        endDate: _end!,
        budget: budget,
        currency: _currency,
        cover: _cover,
      );
    } else {
      e.name = _name.text.trim();
      e.destination = _destination;
      e.startDate = _start!;
      e.endDate = _end!;
      e.budget = budget;
      e.currency = _currency;
      e.cover = _cover;
      await TripController.instance.updateTrip(e);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.existing == null ? 'New Trip' : 'Edit Trip',
      onSave: (_valid && (widget.existing == null || _dirty)) ? _save : null,
      children: [
        _Field(label: 'Trip name', controller: _name, hint: 'Japan 2026'),
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
        const SizedBox(height: 20),
        Text('COVER', style: AppText.label(10)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: TripCover.values.map((c) {
            final selected = c == _cover;
            return GestureDetector(
              onTap: () => setState(() => _cover = c),
              child: Container(
                width: 52,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: tripCovers[c]!,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: selected
                        ? AppColors.accent
                        : Colors.white.withValues(alpha: 0.08),
                    width: selected ? 2 : 1,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
