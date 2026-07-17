import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:plansync/ui/shared/money_field.dart';
import 'package:plansync/utils/format.dart';

void main() {
  testWidgets('money field groups thousands with commas and parses back', (tester) async {
    final controller = TextEditingController();
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MoneyField(controller: controller, symbol: '\$')),
    ));

    await tester.enterText(find.byType(TextField), '1000');
    await tester.pump();
    expect(controller.text, '1,000');
    expect(parseMoney(controller.text), 1000);

    await tester.enterText(find.byType(TextField), '1234567.5');
    await tester.pump();
    expect(controller.text, '1,234,567.5');
    expect(parseMoney(controller.text), 1234567.5);

    // Caps to two decimals.
    await tester.enterText(find.byType(TextField), '12.999');
    await tester.pump();
    expect(controller.text, '12.99');
  });

  test('moneyInput prefills with grouping, empty for zero', () {
    expect(moneyInput(1000), '1,000');
    expect(moneyInput(1234.5), '1,234.5');
    expect(moneyInput(0), '');
  });
}
