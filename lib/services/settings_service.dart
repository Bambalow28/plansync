import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The user's app-wide preferences, persisted in shared_preferences. Load once
/// at startup ([load]); every setter saves, then notifies listeners.
class SettingsService extends ChangeNotifier {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const currencies = ['USD', 'EUR', 'GBP', 'JPY', 'CAD', 'AUD', 'MXN'];

  static const _autoBackupKey = 'settings.icloudAutoBackup';
  static const _remindersKey = 'settings.remindersEnabled';
  static const _liveActivityKey = 'settings.liveActivityEnabled';
  static const _currencyKey = 'settings.defaultCurrency';
  static const _lastBackupKey = 'settings.lastBackupAt';
  static const _restorePromptedKey = 'settings.restorePrompted';

  /// Null until [load]; getters fall back to defaults so screens built in
  /// tests (or before startup finishes) never crash.
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    notifyListeners();
  }

  /// Keep the iCloud copy current after every change.
  bool get autoBackup => _prefs?.getBool(_autoBackupKey) ?? true;

  /// "Heads up" notifications before timed plans.
  bool get remindersEnabled => _prefs?.getBool(_remindersKey) ?? true;

  /// The next plan on the Lock Screen.
  bool get liveActivityEnabled => _prefs?.getBool(_liveActivityKey) ?? true;

  /// Preselected when creating a trip.
  String get defaultCurrency {
    final c = _prefs?.getString(_currencyKey);
    return currencies.contains(c) ? c! : 'USD';
  }

  DateTime? get lastBackupAt {
    final raw = _prefs?.getString(_lastBackupKey);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  /// Whether the "restore your trips?" offer has already been shown on this
  /// install, so declining it doesn't nag on every launch.
  bool get restorePrompted => _prefs?.getBool(_restorePromptedKey) ?? false;

  Future<void> _set(Future<bool> Function(SharedPreferences p) write) async {
    await write(_prefs ??= await SharedPreferences.getInstance());
    notifyListeners();
  }

  Future<void> setAutoBackup(bool v) => _set((p) => p.setBool(_autoBackupKey, v));
  Future<void> setRemindersEnabled(bool v) => _set((p) => p.setBool(_remindersKey, v));
  Future<void> setLiveActivityEnabled(bool v) => _set((p) => p.setBool(_liveActivityKey, v));
  Future<void> setDefaultCurrency(String v) => _set((p) => p.setString(_currencyKey, v));
  Future<void> setLastBackupAt(DateTime v) =>
      _set((p) => p.setString(_lastBackupKey, v.toIso8601String()));
  Future<void> setRestorePrompted() => _set((p) => p.setBool(_restorePromptedKey, true));
}
