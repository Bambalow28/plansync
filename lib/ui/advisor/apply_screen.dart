import 'package:flutter/material.dart';
import '../../models/place.dart';
import '../../services/advisor_workspace.dart';
import '../../theme/app_theme.dart';
import '../shared/place_search_field.dart';
import 'advisor_dashboard_screen.dart';

/// Applying to become an advisor.
///
/// One scrolling form rather than a wizard: the same shape as the trip form
/// the user already knows, and it lets an applicant see the whole ask before
/// committing to the first answer — which matters when the thing being asked
/// for is a pitch rather than a set of facts.
class ApplyScreen extends StatefulWidget {
  const ApplyScreen({super.key});

  @override
  State<ApplyScreen> createState() => _ApplyScreenState();
}

class _ApplyScreenState extends State<ApplyScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _years = TextEditingController();
  final _rate = TextEditingController();

  Place? _city;
  bool _allAround = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _headline, _bio, _years, _rate]) {
      c.addListener(_changed);
    }
  }

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final c in [_name, _email, _headline, _bio, _years, _rate]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _email.text.trim().contains('@') &&
      _headline.text.trim().isNotEmpty &&
      _bio.text.trim().length >= 40 &&
      (_allAround || _city != null);

  Future<void> _submit() async {
    await AdvisorWorkspace.instance.setStatus(AdvisorStatus.pending);
    if (mounted) setState(() => _submitted = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: Text(_submitted ? 'Application sent' : 'Become an advisor',
            style: AppText.display(19)),
      ),
      body: SafeArea(
        top: false,
        child: _submitted ? const _SubmittedView() : _form(),
      ),
    );
  }

  Widget _form() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
      children: [
        Text(
          'Travellers pick advisors by what they know, not by how much they have '
          'written. Tell us the place you could plan from memory.',
          style: AppText.body(15, color: AppColors.textSecondary).copyWith(height: 1.5),
        ),
        const SizedBox(height: 12),
        Text(
          'Every application is read by a person. Expect a reply within a week.',
          style: AppText.label(11, color: AppColors.textMuted),
        ),
        const SizedBox(height: 30),

        _SectionLabel('YOU'),
        _Field(label: 'Full name', controller: _name, hint: 'As travellers should see it'),
        _Field(label: 'Email', controller: _email, hint: 'Where we send our decision', keyboardType: TextInputType.emailAddress),

        const SizedBox(height: 26),
        _SectionLabel('WHAT YOU KNOW'),
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'I plan trips anywhere, not one city',
                  style: AppText.body(14, color: AppColors.textSecondary),
                ),
              ),
              Switch(
                value: _allAround,
                activeThumbColor: Colors.black,
                activeTrackColor: AppColors.accent,
                onChanged: (v) => setState(() {
                  _allAround = v;
                  if (v) _city = null;
                }),
              ),
            ],
          ),
        ),
        if (!_allAround) ...[
          Text('CITY OF EXPERTISE', style: AppText.label(10)),
          const SizedBox(height: 8),
          PlaceSearchField(
            initialValue: _city,
            hint: 'Search city — e.g. Lisbon',
            onSelected: (p) => setState(() => _city = p),
          ),
          const SizedBox(height: 18),
        ],
        _Field(
          label: 'One-line headline',
          controller: _headline,
          hint: 'What you are known for',
        ),
        _Field(
          label: 'About you',
          controller: _bio,
          hint: 'Why a traveller should trust your plan. A short paragraph is plenty.',
          maxLines: 5,
          counter: '${_bio.text.trim().length} / 40 minimum',
          counterMet: _bio.text.trim().length >= 40,
        ),
        _Field(
          label: 'Years planning trips',
          controller: _years,
          hint: 'Optional',
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 26),
        _SectionLabel('YOUR RATE'),
        _Field(
          label: 'Price per plan (USD)',
          controller: _rate,
          hint: 'Leave blank to take requests free',
          keyboardType: TextInputType.number,
        ),

        const SizedBox(height: 34),
        _SubmitButton(enabled: _valid, onTap: _submit),
        const SizedBox(height: 14),
        Text(
          'You can add the places you have travelled once you are approved.',
          textAlign: TextAlign.center,
          style: AppText.label(10, color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Text(text, style: AppText.label(11, color: AppColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(child: Divider(height: 1, color: AppColors.hairline)),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final String? counter;
  final bool counterMet;

  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.counter,
    this.counterMet = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label.toUpperCase(), style: AppText.label(10)),
              if (counter != null) ...[
                const Spacer(),
                Text(
                  counter!,
                  style: AppText.label(
                    9,
                    color: counterMet ? AppColors.accent : AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: AppText.body(15),
            cursorColor: AppColors.accent,
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: AppText.body(14, color: AppColors.textMuted),
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

class _SubmitButton extends StatelessWidget {
  final bool enabled;
  final VoidCallback onTap;
  const _SubmitButton({required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            'Send application',
            style: AppText.body(15, color: Colors.black, weight: FontWeight.w700),
          ),
        ),
      ),
    );
  }
}

/// Post-submit state. Says plainly that a person reads this, and carries the
/// mockup's approval shortcut so both sides of the flow can be walked through
/// without a backend.
class _SubmittedView extends StatelessWidget {
  const _SubmittedView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 30, 28, 40),
      children: [
        Center(
          child: Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
            ),
            child: Icon(Icons.mark_email_read_rounded, size: 32, color: AppColors.accent),
          ),
        ),
        const SizedBox(height: 26),
        Text(
          'With us now',
          textAlign: TextAlign.center,
          style: AppText.display(26),
        ),
        const SizedBox(height: 10),
        Text(
          'Every application is read by hand, so this takes a few days rather than '
          'a few minutes. We will email you either way.',
          textAlign: TextAlign.center,
          style: AppText.body(14, color: AppColors.textSecondary).copyWith(height: 1.5),
        ),
        const SizedBox(height: 36),
        const _MockupApprovalShortcut(),
      ],
    );
  }
}

/// Mockup scaffolding, labelled as such so it is never mistaken for product.
/// Real approval is the owner's decision on a server that does not exist yet.
class _MockupApprovalShortcut extends StatelessWidget {
  const _MockupApprovalShortcut();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MOCKUP ONLY', style: AppText.label(9, color: AppColors.warning)),
          const SizedBox(height: 8),
          Text(
            'There is no server to review this, so nothing was sent. Jump to the '
            'approved state to see the advisor dashboard.',
            style: AppText.body(13, color: AppColors.textSecondary).copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () async {
              await AdvisorWorkspace.instance.setStatus(AdvisorStatus.approved);
              if (!context.mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const AdvisorDashboardScreen()),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.45)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Simulate approval',
                    style: AppText.body(13, color: AppColors.accent, weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Icon(Icons.arrow_forward_rounded, size: 15, color: AppColors.accent),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
