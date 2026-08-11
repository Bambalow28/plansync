import 'package:shared_preferences/shared_preferences.dart';

enum ReviewView { postcard, map }

/// Remembers which Trip Review layout the user prefers — a device-level
/// display preference (like light/dark mode), not trip data, so it lives
/// outside the Trip model.
class ReviewViewService {
  ReviewViewService._();
  static final ReviewViewService instance = ReviewViewService._();

  static const _key = 'trip_review_view_v1';

  Future<ReviewView> getView() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key) == 'map' ? ReviewView.map : ReviewView.postcard;
  }

  Future<void> setView(ReviewView view) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, view.name);
  }
}
