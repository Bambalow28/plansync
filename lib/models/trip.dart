import 'package:flutter/material.dart';
import 'expense.dart';
import 'itinerary_item.dart';
import 'place.dart';

/// A cover gradient option for a trip card — the visual identity of the trip.
enum TripCover { teal, sunset, violet, ocean, forest, slate }

const Map<TripCover, List<Color>> tripCovers = {
  TripCover.teal: [Color(0xFF134E4A), Color(0xFF0C2A2A)],
  TripCover.sunset: [Color(0xFF7C2D4E), Color(0xFF2E1430)],
  TripCover.violet: [Color(0xFF3B2D6E), Color(0xFF17122E)],
  TripCover.ocean: [Color(0xFF0E4A5A), Color(0xFF051C26)],
  TripCover.forest: [Color(0xFF1A4A30), Color(0xFF08200F)],
  TripCover.slate: [Color(0xFF2A3340), Color(0xFF12161C)],
};

class Trip {
  final String id;
  String name;
  Place? destination;
  DateTime startDate;
  DateTime endDate;
  double budget;
  String currency;
  TripCover cover;
  List<ItineraryItem> items;

  /// Trip-level costs booked ahead (hotels, flights, etc.).
  List<Expense> expenses;

  String get destinationLabel => destination?.label ?? '';
  bool get hasDestination => destination != null;

  Trip({
    required this.id,
    required this.name,
    this.destination,
    required this.startDate,
    required this.endDate,
    this.budget = 0,
    this.currency = 'USD',
    this.cover = TripCover.teal,
    List<ItineraryItem>? items,
    List<Expense>? expenses,
  })  : items = items ?? [],
        expenses = expenses ?? [];

  /// Inclusive day count.
  int get dayCount =>
      DateTime(endDate.year, endDate.month, endDate.day)
          .difference(DateTime(startDate.year, startDate.month, startDate.day))
          .inDays +
      1;

  /// Each calendar day of the trip, in order.
  List<DateTime> get days => List.generate(
    dayCount,
    (i) => DateTime(startDate.year, startDate.month, startDate.day + i),
  );

  /// True once the trip has fully ended (relative to today) — the signal for
  /// whether a trip gets the Trip Review summary or opens straight into the
  /// full itinerary.
  bool get isPast {
    final today = DateTime.now();
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    return end.isBefore(DateTime(today.year, today.month, today.day));
  }

  /// Days remaining before the trip starts — 0 once it's begun. Feeds the
  /// home card's countdown badge.
  int get daysUntilStart {
    final today = DateTime.now();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    final diff = start.difference(todayOnly).inDays;
    return diff < 0 ? 0 : diff;
  }

  double get spent =>
      items.fold(0.0, (sum, i) => sum + i.cost) + expenses.fold(0.0, (sum, e) => sum + e.amount);
  double get remaining => budget - spent;

  List<ItineraryItem> itemsOn(DateTime day) {
    final list = items.where((i) => i.occursOn(day)).toList()
      ..sort((a, b) => a.displaySortKey(day).compareTo(b.displaySortKey(day)));
    return list;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'destination': destination?.toJson(),
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'budget': budget,
    'currency': currency,
    'cover': cover.name,
    'items': items.map((i) => i.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
  };

  factory Trip.fromJson(Map<String, dynamic> j) => Trip(
    id: j['id'] as String,
    name: j['name'] as String,
    destination: switch (j['destination']) {
      final Map<String, dynamic> m => Place.fromJson(m),
      final String s when s.isNotEmpty => Place(city: s),
      _ => null,
    },
    startDate: DateTime.parse(j['startDate'] as String),
    endDate: DateTime.parse(j['endDate'] as String),
    budget: (j['budget'] as num?)?.toDouble() ?? 0,
    currency: (j['currency'] ?? 'USD') as String,
    cover: TripCover.values.firstWhere(
      (c) => c.name == (j['cover'] ?? 'teal'),
      orElse: () => TripCover.teal,
    ),
    items: ((j['items'] ?? []) as List)
        .map((e) => ItineraryItem.fromJson(e as Map<String, dynamic>))
        .toList(),
    expenses: ((j['expenses'] ?? []) as List)
        .map((e) => Expense.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
