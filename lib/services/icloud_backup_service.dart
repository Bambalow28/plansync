import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../models/trip.dart';
import 'settings_service.dart';
import 'storage_service.dart';

const _channel = MethodChannel('plansync/icloud');

/// What an iCloud backup holds, read from its small `backup.json` marker.
class BackupInfo {
  final DateTime savedAt;
  final int tripCount;
  const BackupInfo(this.savedAt, this.tripCount);
}

enum BackupResult { ok, unavailable, failed }

/// Backs trips and their attached documents up to the app's iCloud container
/// (`Documents/PlanSync Backup/`) and restores them after a reinstall.
///
/// Layout: `trips.json` (the same JSON the app stores), `backup.json`
/// (`{savedAt, tripCount}`), `attachments/<file>` mirroring the local folder.
/// Restore is additive: trips already on this device are kept, so it can never
/// throw local work away.
///
/// ponytail: plain file copies, no NSFileCoordinator / metadata query — the
/// last writer wins and iCloud uploads in its own time. Add coordination if
/// two devices ever back up to the same account concurrently.
class ICloudBackupService {
  ICloudBackupService._();
  static final ICloudBackupService instance = ICloudBackupService._();

  static const _folder = 'PlanSync Backup';

  Timer? _debounce;
  bool _running = false;

  Future<Directory?> _backupDir() async {
    try {
      final docs = await _channel.invokeMethod<String>('containerPath');
      if (docs == null) return null;
      final dir = Directory('$docs/$_folder');
      await dir.create(recursive: true);
      return dir;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null; // Android / tests: no iCloud.
    }
  }

  Future<Directory> _localAttachments() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/attachments');
  }

  /// Backs up a moment after the last change, when auto backup is on. Called
  /// on every trip save, so a burst of edits makes one copy.
  void scheduleBackup() {
    // iCloud Drive is an iOS thing here; elsewhere (and in tests) no timer.
    if (!Platform.isIOS || !SettingsService.instance.autoBackup) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 8), () => backupNow());
  }

  Future<BackupResult> backupNow() async {
    if (_running) return BackupResult.ok;
    _running = true;
    try {
      final dir = await _backupDir();
      if (dir == null) return BackupResult.unavailable;
      final raw = await StorageService.instance.readRaw() ?? '[]';
      final tripCount = (jsonDecode(raw) as List).length;
      await _writeAtomic(File('${dir.path}/trips.json'), raw);

      final local = await _localAttachments();
      final remote = Directory('${dir.path}/attachments');
      var copied = 0;
      if (local.existsSync()) {
        await remote.create(recursive: true);
        for (final f in local.listSync().whereType<File>()) {
          final name = f.uri.pathSegments.last;
          final dest = File('${remote.path}/$name');
          if (!dest.existsSync() || dest.lengthSync() != f.lengthSync()) {
            await f.copy(dest.path);
            copied++;
          }
        }
      }
      final now = DateTime.now();
      // Marker last, so a half-finished backup never advertises itself.
      await _writeAtomic(
        File('${dir.path}/backup.json'),
        jsonEncode({'savedAt': now.toIso8601String(), 'tripCount': tripCount}),
      );
      await SettingsService.instance.setLastBackupAt(now);
      debugPrint('iCloud backup: $tripCount trips, $copied files copied');
      return BackupResult.ok;
    } catch (e) {
      debugPrint('iCloud backup failed: $e');
      return BackupResult.failed;
    } finally {
      _running = false;
    }
  }

  Future<void> _writeAtomic(File file, String contents) async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(contents);
    if (file.existsSync()) await file.delete();
    await tmp.rename(file.path);
  }

  /// A file another install uploaded is only a placeholder until iOS downloads
  /// it: ask, then wait a little for it to land. False if it never does.
  Future<bool> _fetch(File file) async {
    if (file.existsSync()) return true;
    try {
      await _channel.invokeMethod('startDownload', file.path);
    } catch (_) {}
    for (var i = 0; i < 30; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (file.existsSync()) return true;
    }
    return false;
  }

  /// The backup in iCloud, or null when there is none (or iCloud is off).
  Future<BackupInfo?> latest() async {
    final dir = await _backupDir();
    if (dir == null) return null;
    final marker = File('${dir.path}/backup.json');
    if (!await _fetch(marker)) return null;
    try {
      final j = jsonDecode(await marker.readAsString()) as Map<String, dynamic>;
      return BackupInfo(DateTime.parse(j['savedAt'] as String), j['tripCount'] as int);
    } catch (_) {
      return null;
    }
  }

  /// The trips stored in the backup, with their documents copied down next to
  /// the app's own. Null when the backup can't be read.
  Future<List<Trip>?> readTrips() async {
    final dir = await _backupDir();
    if (dir == null) return null;
    final file = File('${dir.path}/trips.json');
    if (!await _fetch(file)) return null;
    try {
      final trips = (jsonDecode(await file.readAsString()) as List)
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
      final local = await _localAttachments();
      await local.create(recursive: true);
      for (final t in trips) {
        for (final a in t.items.expand((i) => i.attachments)) {
          final name = a.relativePath.split('/').last;
          final dest = File('${local.path}/$name');
          if (dest.existsSync()) continue;
          final src = File('${dir.path}/attachments/$name');
          if (await _fetch(src)) await src.copy(dest.path);
        }
      }
      return trips;
    } catch (e) {
      debugPrint('iCloud restore read failed: $e');
      return null;
    }
  }
}
