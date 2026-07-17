import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../theme/app_theme.dart';

/// A money input with the currency symbol as a fixed left section. Built as a
/// plain TextField inside a bordered row (not a `prefixIcon`, which left the
/// field hard to focus), so tapping anywhere focuses and accepts decimals.
class MoneyField extends StatefulWidget {
  final TextEditingController controller;
  final String symbol;
  final String hint;
  final bool readOnly;

  const MoneyField({
    super.key,
    required this.controller,
    required this.symbol,
    this.hint = '0.00',
    this.readOnly = false,
  });

  @override
  State<MoneyField> createState() => _MoneyFieldState();
}

class _MoneyFieldState extends State<MoneyField> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus && !widget.readOnly;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: focused ? AppColors.accent : Colors.white.withValues(alpha: 0.06),
          width: focused ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 14, right: 8),
            child: Text(widget.symbol, style: AppText.body(15, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              readOnly: widget.readOnly,
              canRequestFocus: !widget.readOnly,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_ThousandsFormatter()],
              style: AppText.body(15),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: widget.hint,
                hintStyle: AppText.body(15, color: AppColors.textMuted),
                contentPadding: const EdgeInsets.only(right: 14, top: 14, bottom: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Live formats a money input: keeps digits and a single decimal point (max 2
/// decimals) and groups the integer part with commas (1000 → 1,000).
class _ThousandsFormatter extends TextInputFormatter {
  static final _intFmt = NumberFormat('#,##0');
  static final _digit = RegExp(r'[0-9]');
  static final _digitOrDot = RegExp(r'[0-9.]');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text;

    // Sanitize: digits + one dot + at most two decimals.
    final buf = StringBuffer();
    var seenDot = false;
    var decimals = 0;
    for (final ch in raw.split('')) {
      if (ch == '.') {
        if (seenDot) continue;
        seenDot = true;
        buf.write('.');
      } else if (_digit.hasMatch(ch)) {
        if (seenDot) {
          if (decimals >= 2) continue;
          decimals++;
        }
        buf.write(ch);
      }
    }
    final cleaned = buf.toString();
    if (cleaned.isEmpty) return const TextEditingValue(text: '');

    final dot = cleaned.indexOf('.');
    final intDigits = (dot >= 0 ? cleaned.substring(0, dot) : cleaned).replaceAll(RegExp(r'[^0-9]'), '');
    final dec = dot >= 0 ? cleaned.substring(dot + 1) : null;

    final grouped = intDigits.isEmpty ? (dot >= 0 ? '0' : '') : _intFmt.format(int.parse(intDigits));
    final result = dot >= 0 ? '$grouped.$dec' : grouped;

    // Keep the cursor in roughly the same logical spot (count digits/dot
    // before the old cursor, then map into the regrouped string).
    final base = newValue.selection.baseOffset;
    var digitsBefore = 0;
    for (var i = 0; i < base && i < raw.length; i++) {
      if (_digitOrDot.hasMatch(raw[i])) digitsBefore++;
    }
    var offset = result.length, count = 0;
    for (var i = 0; i < result.length; i++) {
      if (count >= digitsBefore) {
        offset = i;
        break;
      }
      if (_digitOrDot.hasMatch(result[i])) count++;
    }

    return TextEditingValue(text: result, selection: TextSelection.collapsed(offset: offset));
  }
}
