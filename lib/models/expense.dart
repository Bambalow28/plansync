import 'category.dart';

/// A trip-level cost not tied to a specific day's plan — e.g. a hotel or
/// flight booked ahead of time. Counts toward the trip budget.
class Expense {
  final String id;
  String label;
  double amount;
  PlanCategory category;

  Expense({
    required this.id,
    required this.label,
    this.amount = 0,
    this.category = PlanCategory.other,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'amount': amount,
        'category': category.name,
      };

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        label: (j['label'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        category: categoryFromName((j['category'] ?? 'other') as String),
      );
}
