import 'package:intl/intl.dart';

/// Common currency symbols; falls back to the code itself.
const Map<String, String> currencySymbols = {
  'USD': '\$',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CAD': 'C\$',
  'AUD': 'A\$',
  'MXN': 'MX\$',
};

String symbolFor(String currency) => currencySymbols[currency] ?? '$currency ';

String money(double amount, String currency) {
  final sym = symbolFor(currency);
  final whole = amount == amount.roundToDouble();
  final formatted = NumberFormat(whole ? '#,##0' : '#,##0.00').format(amount);
  return '$sym$formatted';
}

/// Parses a money text field value, ignoring thousands separators.
double parseMoney(String text) => double.tryParse(text.replaceAll(',', '').trim()) ?? 0;

/// Formats a value for prefilling a money input — comma-grouped, with up to
/// two decimals and no trailing zeros. Empty for zero/negative.
String moneyInput(double value) => value > 0 ? NumberFormat('#,##0.##').format(value) : '';

/// Minutes-from-midnight → "9:30 AM".
String timeLabel(int minutes) {
  final h = minutes ~/ 60;
  final m = minutes % 60;
  final period = h < 12 ? 'AM' : 'PM';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12:${m.toString().padLeft(2, '0')} $period';
}

String dayWeekday(DateTime d) => DateFormat('EEE').format(d); // Mon
String dayNum(DateTime d) => DateFormat('d').format(d); // 5
String monthShort(DateTime d) => DateFormat('MMM').format(d); // Jun
String fullDate(DateTime d) =>
    DateFormat('EEEE, MMM d').format(d); // Monday, Jun 5
String dateTimeLabel(DateTime d) => DateFormat('MMM d • h:mm a').format(d);
String shortRange(DateTime a, DateTime b) {
  final sameMonth = a.month == b.month && a.year == b.year;
  if (sameMonth) {
    return '${DateFormat('MMM d').format(a)} – ${DateFormat('d').format(b)}';
  }
  return '${DateFormat('MMM d').format(a)} – ${DateFormat('MMM d').format(b)}';
}

/// A country's flag emoji from its 2-letter ISO code (e.g. "JP" → 🇯🇵).
/// Returns '' for an empty/invalid code.
String flagEmoji(String countryCode) {
  final cc = countryCode.trim().toUpperCase();
  if (cc.length != 2) return '';
  const base = 0x1F1E6; // regional indicator 'A'
  final a = cc.codeUnitAt(0), b = cc.codeUnitAt(1);
  if (a < 0x41 || a > 0x5A || b < 0x41 || b > 0x5A) return '';
  return String.fromCharCode(base + (a - 0x41)) +
      String.fromCharCode(base + (b - 0x41));
}

/// Short "days remaining" status for a trip, relative to [now] (defaults to
/// today). Used on trip cards in place of a plan count.
String tripCountdownLabel(DateTime start, DateTime end, {DateTime? now}) {
  final today = _dateOnly(now ?? DateTime.now());
  final s = _dateOnly(start);
  final e = _dateOnly(end);
  if (e.isBefore(today)) return 'Ended';
  if (!s.isAfter(today) && !e.isBefore(today)) {
    // In progress.
    final left = e.difference(today).inDays;
    if (left == 0) return 'Last day';
    return 'Ongoing · $left day${left == 1 ? '' : 's'} left';
  }
  // Upcoming.
  final until = s.difference(today).inDays;
  if (until == 0) return 'Starts today';
  if (until == 1) return 'Tomorrow';
  return 'In $until days';
}

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
