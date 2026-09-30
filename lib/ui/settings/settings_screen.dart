import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../controllers/trip_controller.dart';
import '../../services/icloud_backup_service.dart';
import '../../services/live_activity_service.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../../services/storage_service.dart';
import '../../theme/app_theme.dart';
import '../onboarding/onboarding_screen.dart';

/// App settings: iCloud backup and restore, reminders, defaults, and the
/// user's data. Everything here is wired to real behaviour — no dead toggles.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = SettingsService.instance;
  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _ago(DateTime? t) {
    if (t == null) return 'Never';
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
  }

  Future<void> _backupNow() async {
    setState(() => _busy = true);
    final result = await ICloudBackupService.instance.backupNow();
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(switch (result) {
      BackupResult.ok => 'Backed up to iCloud',
      BackupResult.unavailable => 'iCloud isn’t available. Sign in to iCloud in Settings.',
      BackupResult.failed => 'Backup failed. Try again in a moment.',
    });
  }

  Future<bool> _confirm(String title, String body, String action, {bool destructive = false}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(title, style: AppText.display(20)),
        content: Text(body, style: AppText.body(14, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              action,
              style: AppText.body(14, color: destructive ? AppColors.warning : AppColors.accent),
            ),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _restore() async {
    setState(() => _busy = true);
    final info = await ICloudBackupService.instance.latest();
    if (!mounted) return;
    setState(() => _busy = false);
    if (info == null) {
      _toast('No iCloud backup found.');
      return;
    }
    final go = await _confirm(
      'Restore from iCloud?',
      'Adds the ${info.tripCount} trip${info.tripCount == 1 ? '' : 's'} saved ${_ago(info.savedAt)}. '
          'Trips already on this phone are kept.',
      'Restore',
    );
    if (!go || !mounted) return;
    setState(() => _busy = true);
    final trips = await ICloudBackupService.instance.readTrips();
    final added = trips == null ? null : await TripController.instance.mergeTrips(trips);
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(
      added == null
          ? 'Couldn’t read the backup. Try again in a moment.'
          : added == 0
              ? 'Everything in the backup is already on this phone.'
              : 'Restored $added trip${added == 1 ? '' : 's'}.',
    );
  }

  Future<void> _export() async {
    final raw = await StorageService.instance.readRaw();
    if (raw == null || raw == '[]') {
      _toast('No trips to export yet.');
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/plansync-trips.json')..writeAsStringSync(raw);
    if (!mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  Future<void> _deleteAll() async {
    final go = await _confirm(
      'Delete all trips?',
      'Removes every trip, plan and attached document from this phone. '
          'An iCloud backup isn’t touched, so you can still restore from it.',
      'Delete everything',
      destructive: true,
    );
    if (!go) return;
    await TripController.instance.deleteAll();
    _toast('All trips deleted.');
  }

  Future<void> _pickCurrency() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in SettingsService.currencies)
              ListTile(
                minTileHeight: 52,
                title: Text(c, style: AppText.body(16)),
                trailing: c == _settings.defaultCurrency
                    ? Icon(Icons.check_rounded, color: AppColors.accent)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (picked != null) await _settings.setDefaultCurrency(picked);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _settings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.background,
          scrolledUnderElevation: 0,
          title: Text('Settings', style: AppText.display(26)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 48),
          children: [
            _Section(
              title: 'ICLOUD BACKUP',
              footer: 'Your trips and their documents are copied to your private iCloud. '
                  'After a reinstall or on a new phone, restore them here.',
              children: [
                _SwitchRow(
                  label: 'Back up automatically',
                  value: _settings.autoBackup,
                  onChanged: (v) async {
                    await _settings.setAutoBackup(v);
                    if (v) ICloudBackupService.instance.scheduleBackup();
                  },
                ),
                _ActionRow(
                  label: 'Back up now',
                  detail: 'Last backup: ${_ago(_settings.lastBackupAt)}',
                  busy: _busy,
                  onTap: _busy ? null : _backupNow,
                ),
                _ActionRow(label: 'Restore from iCloud', onTap: _busy ? null : _restore),
              ],
            ),
            _Section(
              title: 'NOTIFICATIONS',
              children: [
                _SwitchRow(
                  label: 'Plan reminders',
                  value: _settings.remindersEnabled,
                  onChanged: (v) async {
                    await _settings.setRemindersEnabled(v);
                    await NotificationService.instance.syncAll(TripController.instance.trips);
                  },
                ),
                _SwitchRow(
                  label: 'Next plan on Lock Screen',
                  value: _settings.liveActivityEnabled,
                  onChanged: (v) async {
                    await _settings.setLiveActivityEnabled(v);
                    await LiveActivityService.instance.syncNext(TripController.instance.trips);
                  },
                ),
              ],
            ),
            _Section(
              title: 'NEW TRIPS',
              children: [
                _ActionRow(
                  label: 'Default currency',
                  detail: _settings.defaultCurrency,
                  inlineDetail: true,
                  onTap: _pickCurrency,
                ),
              ],
            ),
            _Section(
              title: 'YOUR DATA',
              children: [
                _ActionRow(label: 'Export trips', detail: 'JSON file', inlineDetail: true, onTap: _export),
                _ActionRow(label: 'Delete all trips', destructive: true, onTap: _deleteAll),
              ],
            ),
            _Section(
              title: 'HELP',
              children: [
                _ActionRow(
                  label: 'Replay intro',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String? footer;
  final List<Widget> children;
  const _Section({required this.title, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
            child: Text(title, style: AppText.label(12, color: AppColors.textSecondary)),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.hairline),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 16, color: AppColors.hairline),
                  children[i],
                ],
              ],
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
              child: Text(footer!, style: AppText.body(13, color: AppColors.textSecondary)),
            ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppText.body(16))),
              Switch.adaptive(
                value: value,
                activeTrackColor: AppColors.accent,
                onChanged: onChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final String label;
  final String? detail;
  final bool destructive;
  final bool busy;

  /// Show [detail] on the right (a current value) instead of under the label.
  final bool inlineDetail;
  final VoidCallback? onTap;
  const _ActionRow({
    required this.label,
    this.detail,
    this.inlineDetail = false,
    this.destructive = false,
    this.busy = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppText.body(
                        16,
                        color: destructive
                            ? AppColors.warning
                            : (onTap == null ? AppColors.textMuted : AppColors.textPrimary),
                      ),
                    ),
                    if (detail != null && !inlineDetail)
                      Text(detail!, style: AppText.body(13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (detail != null && inlineDetail)
                Text(detail!, style: AppText.body(15, color: AppColors.textSecondary))
              else
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
