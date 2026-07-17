import 'package:flutter/material.dart';

/// An itinerary item's type, which doubles as its budget bucket.
enum PlanCategory { flight, lodging, food, activity, transport, sightseeing, shopping, other }

class CategoryStyle {
  final String label;
  final IconData icon;
  final Color color;
  const CategoryStyle(this.label, this.icon, this.color);
}

const Map<PlanCategory, CategoryStyle> categoryStyles = {
  PlanCategory.flight: CategoryStyle('Flight', Icons.flight_takeoff_rounded, Color(0xFF60A5FA)),
  PlanCategory.lodging: CategoryStyle('Lodging', Icons.hotel_rounded, Color(0xFFA78BFA)),
  PlanCategory.food: CategoryStyle('Food', Icons.restaurant_rounded, Color(0xFFFB923C)),
  PlanCategory.activity: CategoryStyle('Activity', Icons.local_activity_rounded, Color(0xFF2DD4BF)),
  PlanCategory.sightseeing: CategoryStyle('Sightseeing', Icons.photo_camera_rounded, Color(0xFF34D399)),
  PlanCategory.transport: CategoryStyle('Transport', Icons.directions_subway_rounded, Color(0xFFF472B6)),
  PlanCategory.shopping: CategoryStyle('Shopping', Icons.shopping_bag_rounded, Color(0xFFFBBF24)),
  PlanCategory.other: CategoryStyle('Other', Icons.place_rounded, Color(0xFF94A3B8)),
};

CategoryStyle styleOf(PlanCategory c) => categoryStyles[c]!;

PlanCategory categoryFromName(String name) => PlanCategory.values.firstWhere(
      (c) => c.name == name,
      orElse: () => PlanCategory.other,
    );
