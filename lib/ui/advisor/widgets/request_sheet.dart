import 'package:flutter/material.dart';
import '../../../services/advisor_workspace.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/format.dart';
import '../advisor_travels_screen.dart' show MonogramAvatar;

/// A single traveller's request, opened from the dashboard.
///
/// A sheet rather than a page: accepting or declining is a decision made in
/// the context of the list, and the advisor should land back in that list with
/// the queue visibly one shorter.
class RequestSheet extends StatelessWidget {
  final PlanRequest request;
  const RequestSheet({super.key, required this.request});

  static Future<void> show(BuildContext context, PlanRequest request) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RequestSheet(request: request),
    );
  }

  void _respond(BuildContext context, RequestState state) {
    AdvisorWorkspace.instance.setRequestState(request, state);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final settled = request.state != RequestState.pending;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                children: [
                  Row(
                    children: [
                      MonogramAvatar(name: request.travellerName, size: 46),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(request.travellerName, style: AppText.display(21)),
                            const SizedBox(height: 3),
                            Text(
                              request.daysAgo == 1
                                  ? 'Asked yesterday'
                                  : 'Asked ${request.daysAgo} days ago',
                              style: AppText.label(10, color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _DetailGrid(request: request),
                  const SizedBox(height: 24),
                  Text('WHAT THEY ASKED FOR', style: AppText.label(10)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.hairline),
                    ),
                    child: Text(
                      request.message,
                      style: AppText.body(14, color: AppColors.textSecondary)
                          .copyWith(height: 1.55),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 14, 24, 16),
              child: settled
                  ? _SettledNote(state: request.state)
                  : Row(
                      children: [
                        Expanded(
                          child: _Action(
                            label: 'Decline',
                            onTap: () => _respond(context, RequestState.declined),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: _Action(
                            label: 'Accept request',
                            primary: true,
                            onTap: () => _respond(context, RequestState.accepted),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailGrid extends StatelessWidget {
  final PlanRequest request;
  const _DetailGrid({required this.request});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Line(
          label: 'DESTINATION',
          value: request.destination.label,
        ),
        _Line(
          label: 'DATES',
          value: '${shortRange(request.start, request.end)} · ${request.nights} nights',
        ),
        _Line(
          label: 'TRAVELLERS',
          value: request.partySize == 1 ? 'Solo' : '${request.partySize} people',
        ),
        _Line(
          label: 'BUDGET',
          value: money(request.budget.toDouble(), request.currency),
          accent: true,
          last: true,
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool accent;
  final bool last;
  const _Line({
    required this.label,
    required this.value,
    this.accent = false,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.hairline)),
            ),
      child: Row(
        children: [
          Text(label, style: AppText.label(10, color: AppColors.textMuted)),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: AppText.body(
                14,
                color: accent ? AppColors.accent : AppColors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettledNote extends StatelessWidget {
  final RequestState state;
  const _SettledNote({required this.state});

  @override
  Widget build(BuildContext context) {
    final accepted = state == RequestState.accepted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(
            accepted ? Icons.check_circle_outline_rounded : Icons.do_not_disturb_alt_rounded,
            size: 17,
            color: accepted ? AppColors.accent : AppColors.textMuted,
          ),
          const SizedBox(width: 11),
          Text(
            accepted ? 'You accepted this request.' : 'You declined this request.',
            style: AppText.body(13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _Action({required this.label, required this.onTap, this.primary = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: primary ? AppColors.accentGradient : null,
          borderRadius: BorderRadius.circular(15),
          border: primary ? null : Border.all(color: AppColors.hairline),
        ),
        child: Text(
          label,
          style: AppText.body(
            14,
            color: primary ? Colors.black : AppColors.textSecondary,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
