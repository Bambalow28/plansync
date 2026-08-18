import 'package:flutter/material.dart';
import '../../services/advisor_workspace.dart';
import '../../theme/app_theme.dart';
import 'advisor_profile_screen.dart';

/// Editing what travellers see.
///
/// Every field here is labelled by where it lands on the public page rather
/// than by its database name, and the preview is always reachable — the
/// question an advisor is actually asking is "how does this read to someone
/// deciding", which no form field can answer on its own.
class AdvisorProfileEditorScreen extends StatefulWidget {
  const AdvisorProfileEditorScreen({super.key});

  @override
  State<AdvisorProfileEditorScreen> createState() => _AdvisorProfileEditorScreenState();
}

class _AdvisorProfileEditorScreenState extends State<AdvisorProfileEditorScreen> {
  final _workspace = AdvisorWorkspace.instance;

  late final _headline = TextEditingController(text: _workspace.headline);
  late final _bio = TextEditingController(text: _workspace.bio);
  late final _rate = TextEditingController(text: _workspace.pricePerPlan.toString());
  late List<String> _languages = [..._workspace.languages];

  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_headline, _bio, _rate]) {
      c.addListener(() => setState(() => _dirty = true));
    }
  }

  @override
  void dispose() {
    for (final c in [_headline, _bio, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    _workspace.updateProfile(
      headline: _headline.text.trim(),
      bio: _bio.text.trim(),
      pricePerPlan: int.tryParse(_rate.text.trim()) ?? _workspace.pricePerPlan,
      languages: _languages,
    );
    setState(() => _dirty = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.surfaceHigh,
        content: Text('Profile updated.', style: AppText.body(13)),
      ),
    );
  }

  void _removeLanguage(String language) {
    setState(() {
      _languages = [..._languages]..remove(language);
      _dirty = true;
    });
  }

  Future<void> _addLanguage() async {
    final controller = TextEditingController();
    final added = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text('Add a language', style: AppText.display(19)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: AppText.body(15),
          cursorColor: AppColors.accent,
          decoration: InputDecoration(
            hintText: 'e.g. Italian',
            hintStyle: AppText.body(14, color: AppColors.textMuted),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: AppText.body(14, color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text('Add', style: AppText.body(14, color: AppColors.accent)),
          ),
        ],
      ),
    );
    if (added != null && added.isNotEmpty && !_languages.contains(added)) {
      setState(() {
        _languages = [..._languages, added];
        _dirty = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text('Public profile', style: AppText.display(19)),
        actions: [
          TextButton(
            onPressed: _dirty ? _save : null,
            child: Text(
              'Save',
              style: AppText.body(
                14,
                color: _dirty ? AppColors.accent : AppColors.textMuted,
                weight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          _PreviewRow(
            onTap: () {
              // Preview the unsaved text, so the button answers the question
              // being asked rather than showing the last saved version.
              final draft = AdvisorWorkspace.instance;
              final before = (draft.headline, draft.bio, draft.pricePerPlan, draft.languages);
              draft.updateProfile(
                headline: _headline.text.trim(),
                bio: _bio.text.trim(),
                pricePerPlan: int.tryParse(_rate.text.trim()) ?? draft.pricePerPlan,
                languages: _languages,
              );
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AdvisorProfileScreen(advisor: draft.toPublicAdvisor()),
                ),
              ).then((_) {
                if (_dirty) {
                  // Roll back to what was saved; the draft stays in the fields.
                  draft.updateProfile(
                    headline: before.$1,
                    bio: before.$2,
                    pricePerPlan: before.$3,
                    languages: before.$4,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 26),

          _EditField(
            label: 'HEADLINE',
            help: 'The line under your name on your profile.',
            controller: _headline,
          ),
          _EditField(
            label: 'ABOUT YOU',
            help: 'The paragraph travellers read before deciding.',
            controller: _bio,
            maxLines: 7,
          ),
          _EditField(
            label: 'PRICE PER PLAN (USD)',
            help: 'Zero shows a Free badge on the advisor list.',
            controller: _rate,
            keyboardType: TextInputType.number,
          ),

          Text('LANGUAGES', style: AppText.label(10)),
          const SizedBox(height: 4),
          Text(
            'Shown as chips under your bio.',
            style: AppText.label(9, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final language in _languages)
                _LanguageChip(label: language, onRemove: () => _removeLanguage(language)),
              _AddChip(onTap: _addLanguage),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  final VoidCallback onTap;
  const _PreviewRow({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.visibility_outlined, size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'See it as a traveller does',
                style: AppText.body(14, color: AppColors.accent, weight: FontWeight.w600),
              ),
            ),
            Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.accent),
          ],
        ),
      ),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final String help;
  final TextEditingController controller;
  final int maxLines;
  final TextInputType? keyboardType;

  const _EditField({
    required this.label,
    required this.help,
    required this.controller,
    this.maxLines = 1,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.label(10)),
          const SizedBox(height: 4),
          Text(help, style: AppText.label(9, color: AppColors.textMuted)),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: AppText.body(15).copyWith(height: 1.45),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: AppColors.surfaceLow,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _LanguageChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.label(10, color: AppColors.textSecondary)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, size: 14, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _AddChip extends StatelessWidget {
  final VoidCallback onTap;
  const _AddChip({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.add_rounded, size: 13, color: AppColors.accent),
            const SizedBox(width: 4),
            Text('Add', style: AppText.label(10, color: AppColors.accent)),
          ],
        ),
      ),
    );
  }
}
