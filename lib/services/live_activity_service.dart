import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color;
import 'package:live_activities/live_activities.dart';

import '../models/category.dart';
import '../models/itinerary_item.dart';
import '../models/trip.dart';
import '../utils/format.dart';
import 'settings_service.dart';

/// Shows the user's **next plan** as a Lock Screen / Dynamic Island Live
/// Activity, styled like an in-app plan card. No-op until [init] succeeds and
/// only on iOS 16.1+.
class LiveActivityService {
  LiveActivityService._();
  static final LiveActivityService instance = LiveActivityService._();

  static const _appGroupId = 'group.com.supremolabs.plansync';
  static const _activityId = 'plansync_next';

  final _plugin = LiveActivities();
  bool _enabled = false;
  bool _created = false;

  Future<void> init() async {
    if (!Platform.isIOS) return;
    try {
      await _plugin.init(appGroupId: _appGroupId);
      _enabled = await _plugin.areActivitiesEnabled();
      // Clear any stale activity left over from a previous launch.
      if (_enabled) await _plugin.endAllActivities();
      _created = false;
    } catch (e) {
      debugPrint('LiveActivityService init failed: $e');
      _enabled = false;
    }
  }

  /// The ongoing plan, else the soonest plan starting after now, across all
  /// trips (timed items only).
  ItineraryItem? _nextPlan(List<Trip> trips) {
    final now = DateTime.now();
    ItineraryItem? best;
    for (final trip in trips) {
      for (final it in trip.items) {
        if (it.start == null) continue;
        final end = it.end ?? it.start!;
        final ongoing = !it.start!.isAfter(now) && !end.isBefore(now);
        final upcoming = it.start!.isAfter(now);
        if (!ongoing && !upcoming) continue;
        if (best == null || it.start!.isBefore(best.start!)) best = it;
      }
    }
    return best;
  }

  Map<String, dynamic> _data(ItineraryItem it, Trip trip) {
    final s = styleOf(it.category);
    final range = it.start != null && it.end != null
        ? '${timeLabel(it.startMinutes!)} – ${timeLabel(it.endMinutes!)}'
        : (it.start != null ? timeLabel(it.startMinutes!) : 'Anytime');
    final loc = it.isFlight
        ? [it.departureCode, it.arrivalCode].where((c) => (c ?? '').isNotEmpty).join(' → ')
        : it.locationLabel;
    return {
      'title': it.title,
      'timeRange': range,
      'category': s.label,
      'colorHex': _hex(s.color),
      'location': loc,
      'tripName': trip.name,
    };
  }

  String _hex(Color c) {
    final v = c.toARGB32() & 0xFFFFFF;
    return '#${v.toRadixString(16).padLeft(6, '0')}';
  }

  /// Recompute the next plan and create/update/end the Live Activity to match.
  Future<void> syncNext(List<Trip> trips) async {
    if (!_enabled) return;
    try {
      Trip? owner;
      ItineraryItem? next;
      for (final trip in trips) {
        final candidate = _nextPlan([trip]);
        if (candidate == null) continue;
        if (next == null || candidate.start!.isBefore(next.start!)) {
          next = candidate;
          owner = trip;
        }
      }

      if (!SettingsService.instance.liveActivityEnabled) next = null;
      if (next == null || owner == null) {
        if (_created) {
          await _plugin.endActivity(_activityId);
          _created = false;
        }
        return;
      }

      final data = _data(next, owner);
      if (!_created) {
        await _plugin.createActivity(_activityId, data);
        _created = true;
      } else {
        await _plugin.updateActivity(_activityId, data);
      }
    } catch (e) {
      debugPrint('LiveActivityService syncNext failed: $e');
    }
  }
}
