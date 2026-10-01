import 'package:flutter_test/flutter_test.dart';
import 'package:plansync/services/ai_itinerary_service.dart';

void main() {
  test('parseItems strips fences, keeps costs, drops out-of-range days', () {
    const json = '''```json
[
  {"day": 0, "what": "Tsukiji breakfast", "category": "food", "startTime": "08:00", "endTime": "09:30", "location": "Tsukiji", "cost": 2500, "notes": ""},
  {"day": 5, "what": "Ghost day", "category": "activity", "cost": 1}
]
```''';
    final items = AiItineraryService.parseItems(json, DateTime(2026, 11, 1), 3);
    expect(items, hasLength(1));
    final item = items.single('a');
    expect(item.title, 'Tsukiji breakfast');
    expect(item.cost, 2500);
    expect(item.day, DateTime(2026, 11, 1));
  });
}
