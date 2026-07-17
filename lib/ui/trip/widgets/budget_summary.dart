import 'package:flutter/material.dart';
import '../../../controllers/trip_controller.dart';
import '../../../models/category.dart';
import '../../../models/expense.dart';
import '../../../models/trip.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../../shared/money_field.dart';
import '../../shared/sheet_scaffold.dart';

/// Compact, tappable budget bar — a slim summary that opens a details sheet
/// with the full breakdown. Keeps the trip screen uncluttered.
class BudgetBar extends StatelessWidget {
  final Trip trip;
  const BudgetBar({super.key, required this.trip});

  @override
  Widget build(BuildContext context) {
    final spent = trip.spent;
    final hasBudget = trip.budget > 0;
    final ratio = hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && spent > trip.budget;
    final accent = over ? AppColors.warning : AppColors.accent;

    return GestureDetector(
      onTap: () => _showBudgetDetails(context, trip),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(Icons.account_balance_wallet_rounded, size: 16, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('${money(spent, trip.currency)} spent', style: AppText.body(13, weight: FontWeight.w600)),
                      const Spacer(),
                      Text(
                        hasBudget
                            ? (over ? '${money(spent - trip.budget, trip.currency)} over' : '${money(trip.remaining, trip.currency)} left')
                            : 'No budget',
                        style: AppText.label(11, color: accent),
                      ),
                    ],
                  ),
                  if (hasBudget) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 5,
                        backgroundColor: Colors.black.withValues(alpha: 0.35),
                        valueColor: AlwaysStoppedAnimation(accent),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

void _showBudgetDetails(BuildContext context, Trip trip) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _BudgetDetailsSheet(trip: trip),
  );
}

class _BudgetDetailsSheet extends StatefulWidget {
  final Trip trip;
  const _BudgetDetailsSheet({required this.trip});

  @override
  State<_BudgetDetailsSheet> createState() => _BudgetDetailsSheetState();
}

class _BudgetDetailsSheetState extends State<_BudgetDetailsSheet> {
  Trip get trip => widget.trip;

  int _seq = 0;
  String _newId() => '${DateTime.now().microsecondsSinceEpoch}_exp${_seq++}';

  Future<void> _addExpense() async {
    final expense = await showDialog<Expense>(
      context: context,
      builder: (_) => _ExpenseDialog(currency: trip.currency, newId: _newId),
    );
    if (expense == null) return;
    trip.expenses.add(expense);
    await TripController.instance.updateTrip(trip);
    if (mounted) setState(() {});
  }

  Future<void> _removeExpense(Expense e) async {
    trip.expenses.removeWhere((x) => x.id == e.id);
    await TripController.instance.updateTrip(trip);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final spent = trip.spent;
    final hasBudget = trip.budget > 0;
    final ratio = hasBudget ? (spent / trip.budget).clamp(0.0, 1.0) : 0.0;
    final over = hasBudget && spent > trip.budget;
    final accent = over ? AppColors.warning : AppColors.accent;

    // Breakdown combines planned-item costs and prior expenses by category.
    final byCat = <PlanCategory, double>{};
    for (final item in trip.items) {
      if (item.cost > 0) byCat[item.category] = (byCat[item.category] ?? 0) + item.cost;
    }
    for (final e in trip.expenses) {
      if (e.amount > 0) byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }
    final entries = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return SheetScaffold(
      title: 'Budget',
      showSave: false,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('SPENT', style: AppText.label(9)),
                const SizedBox(height: 4),
                Text(money(spent, trip.currency), style: AppText.display(28)),
              ],
            ),
            const Spacer(),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(over ? 'OVER BUDGET' : 'REMAINING', style: AppText.label(9)),
                const SizedBox(height: 4),
                Text(
                  hasBudget ? money(over ? spent - trip.budget : trip.remaining, trip.currency) : '—',
                  style: AppText.display(28, color: accent),
                ),
              ],
            ),
          ],
        ),
        if (hasBudget) ...[
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor: Colors.black.withValues(alpha: 0.35),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          const SizedBox(height: 8),
          Text('of ${money(trip.budget, trip.currency)} budget', style: AppText.label(11, color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 22),
        Text('BY CATEGORY', style: AppText.label(10)),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          Text('No costs logged yet.', style: AppText.body(13, color: AppColors.textMuted))
        else
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Icon(styleOf(e.key).icon, size: 16, color: styleOf(e.key).color),
                  const SizedBox(width: 10),
                  SizedBox(width: 90, child: Text(styleOf(e.key).label, style: AppText.body(13))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: spent > 0 ? e.value / spent : 0.0,
                        minHeight: 6,
                        backgroundColor: Colors.black.withValues(alpha: 0.3),
                        valueColor: AlwaysStoppedAnimation(styleOf(e.key).color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(money(e.value, trip.currency), style: AppText.label(11, color: AppColors.textSecondary)),
                ],
              ),
            ),
        const SizedBox(height: 22),
        Row(
          children: [
            Text('EXTRA EXPENSES', style: AppText.label(10)),
            const Spacer(),
            Flexible(
              child: Text(
                'Meals, taxis, tips — spend not in a plan',
                textAlign: TextAlign.end,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppText.label(9, color: AppColors.textMuted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final e in trip.expenses) _expenseTile(e),
        GestureDetector(
          onTap: _addExpense,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: AppColors.surfaceLow,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, size: 18, color: AppColors.accent),
                const SizedBox(width: 6),
                Text('Add expense', style: AppText.body(14, color: AppColors.accent)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _expenseTile(Expense e) {
    final s = styleOf(e.category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Icon(s.icon, size: 16, color: s.color),
            const SizedBox(width: 10),
            Expanded(child: Text(e.label, style: AppText.body(14), maxLines: 1, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 8),
            Text(money(e.amount, trip.currency), style: AppText.label(12, color: AppColors.textSecondary)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _removeExpense(e),
              child: Icon(Icons.close_rounded, size: 18, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog to add a prior expense (label, amount, category).
class _ExpenseDialog extends StatefulWidget {
  final String currency;
  final String Function() newId;
  const _ExpenseDialog({required this.currency, required this.newId});

  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _label = TextEditingController();
  final _amount = TextEditingController();
  PlanCategory _category = PlanCategory.food;

  @override
  void initState() {
    super.initState();
    _label.addListener(() => setState(() {}));
    _amount.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid => _label.text.trim().isNotEmpty && parseMoney(_amount.text) > 0;

  OutlineInputBorder _border(Color c) =>
      OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: c));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceHigh,
      title: Text('Add expense', style: AppText.display(20)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _label,
              style: AppText.body(15),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'e.g. Dinner at the night market',
                hintStyle: AppText.body(15, color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surfaceLow,
                enabledBorder: _border(Colors.white.withValues(alpha: 0.06)),
                focusedBorder: _border(AppColors.accent),
              ),
            ),
            const SizedBox(height: 12),
            MoneyField(controller: _amount, symbol: symbolFor(widget.currency)),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PlanCategory.values.map((c) {
                final s = styleOf(c);
                final sel = c == _category;
                return GestureDetector(
                  onTap: () => setState(() => _category = c),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? s.color.withValues(alpha: 0.18) : AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? s.color : Colors.white.withValues(alpha: 0.06)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(s.icon, size: 13, color: sel ? s.color : AppColors.textMuted),
                        const SizedBox(width: 5),
                        Text(s.label, style: AppText.body(12, color: sel ? Colors.white : AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: _valid
              ? () => Navigator.pop(
                    context,
                    Expense(
                      id: widget.newId(),
                      label: _label.text.trim(),
                      amount: parseMoney(_amount.text),
                      category: _category,
                    ),
                  )
              : null,
          child: Text('Add', style: AppText.body(14, color: _valid ? AppColors.accent : AppColors.textMuted)),
        ),
      ],
    );
  }
}

