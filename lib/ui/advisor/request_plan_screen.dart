import 'package:flutter/material.dart';
import '../../data/advisors.dart';
import '../../models/place.dart';
import '../../services/plan_request_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../shared/date_range_dialog.dart';
import '../shared/money_field.dart';
import '../shared/place_search_field.dart';

/// Asking an advisor to plan a trip: dates, party size, budget, and a message
/// — everything the dashboard's request card needs to show the advisor.
class RequestPlanScreen extends StatefulWidget {
  final Advisor advisor;
  const RequestPlanScreen({super.key, required this.advisor});

  @override
  State<RequestPlanScreen> createState() => _RequestPlanScreenState();
}

class _RequestPlanScreenState extends State<RequestPlanScreen> {
  Place? _destination;
  DateTime? _start;
  DateTime? _end;
  int _partySize = 1;
  late final TextEditingController _budget;
  final _message = TextEditingController();
  String _currency = 'USD';

  bool _submitting = false;
  String? _error;

  static const _currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'MXN'];

  @override
  void initState() {
    super.initState();
    _destination = widget.advisor.city;
    _budget = TextEditingController();
  }

  @override
  void dispose() {
    _budget.dispose();
    _message.dispose();
    super.dispose();
  }

  bool get _valid =>
      _destination != null &&
      _start != null &&
      _end != null &&
      !_start!.isAfter(_end!) &&
      _message.text.trim().isNotEmpty;

  Future<void> _pickDates() async {
    final range = await showAppDateRangeDialog(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime(DateTime.now().year + 3),
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

  Future<void> _submit() async {
    if (!_valid || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await PlanRequestService.instance.submit(
        advisorId: widget.advisor.id,
        destination: _destination!,
        start: _start!,
        end: _end!,
        partySize: _partySize,
        budget: parseMoney(_budget.text).round(),
        currency: _currency,
        message: _message.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not send your request. Try again.');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final advisor = widget.advisor;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Request ${advisor.name.split(' ').first}', style: AppText.display(19)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                children: [
                  if (advisor.isAllAround) ...[
                    Text('DESTINATION', style: AppText.label(10)),
                    const SizedBox(height: 8),
                    PlaceSearchField(
                      initialValue: _destination,
                      hint: 'Where do you want to go?',
                      onSelected: (p) => setState(() => _destination = p),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Text('DATES', style: AppText.label(10)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickDates,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.textMuted),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _start != null && _end != null
                                  ? shortRange(_start!, _end!)
                                  : 'Add trip dates',
                              style: AppText.body(
                                15,
                                color: _start != null ? AppColors.textPrimary : AppColors.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('TRAVELLERS', style: AppText.label(10)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      children: [
                        Text(
                          _partySize == 1 ? 'Solo' : '$_partySize people',
                          style: AppText.body(15),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _partySize > 1
                              ? () => setState(() => _partySize--)
                              : null,
                          icon: Icon(Icons.remove_circle_outline_rounded, color: AppColors.textSecondary),
                        ),
                        Text('$_partySize', style: AppText.body(15, weight: FontWeight.w700)),
                        IconButton(
                          onPressed: () => setState(() => _partySize++),
                          icon: Icon(Icons.add_circle_outline_rounded, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('BUDGET (OPTIONAL)', style: AppText.label(10)),
                            const SizedBox(height: 8),
                            MoneyField(controller: _budget, symbol: symbolFor(_currency)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
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
                                  value: _currency,
                                  isExpanded: true,
                                  dropdownColor: AppColors.surfaceHigh,
                                  style: AppText.body(15),
                                  icon: Icon(Icons.expand_more_rounded, color: AppColors.textMuted),
                                  items: _currencies
                                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _currency = v ?? _currency),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text('MESSAGE', style: AppText.label(10)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _message,
                    maxLines: 5,
                    onChanged: (_) => setState(() {}),
                    style: AppText.body(15),
                    cursorColor: AppColors.accent,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'What should they know before they plan this?',
                      hintStyle: AppText.body(14, color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surfaceLow,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.accent),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: AppText.body(13, color: AppColors.warning)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12 + MediaQuery.of(context).padding.bottom),
              child: GestureDetector(
                onTap: _valid && !_submitting ? _submit : null,
                child: Opacity(
                  opacity: _valid && !_submitting ? 1 : 0.4,
                  child: Container(
                    height: 54,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: AppColors.accentGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'Send request',
                      style: AppText.body(16, color: Colors.black, weight: FontWeight.w700),
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
