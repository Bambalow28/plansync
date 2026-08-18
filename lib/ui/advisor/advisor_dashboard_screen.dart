import 'package:flutter/material.dart';
import '../../services/advisor_workspace.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import 'advisor_profile_editor_screen.dart';
import 'advisor_profile_screen.dart';
import 'advisor_travels_screen.dart';
import 'widgets/request_sheet.dart';

/// The advisor's own workspace.
///
/// Requests lead, because that is the only thing on this screen with someone
/// waiting on the other end of it — the profile and travels editors are
/// housekeeping that can be done any time. The public profile is one tap away
/// throughout, since every editing decision here is really a question about
/// how that page will read.
class AdvisorDashboardScreen extends StatelessWidget {
  const AdvisorDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final workspace = AdvisorWorkspace.instance;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ListenableBuilder(
        listenable: workspace,
        builder: (context, _) {
          final pending = [
            for (final r in workspace.requests)
              if (r.state == RequestState.pending) r,
          ];
          final settled = [
            for (final r in workspace.requests)
              if (r.state != RequestState.pending) r,
          ];

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppColors.background,
                surfaceTintColor: Colors.transparent,
                title: Text('Advisor', style: AppText.display(19)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AdvisorProfileScreen(
                          advisor: workspace.toPublicAdvisor(),
                        ),
                      ),
                    ),
                    child: Text(
                      'View public',
                      style: AppText.body(13, color: AppColors.accent, weight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _Identity(workspace: workspace)),
              SliverToBoxAdapter(child: _Numbers(workspace: workspace)),

              _Heading(
                label: 'REQUESTS',
                trailing: pending.isEmpty ? null : '${pending.length} waiting',
              ),
              if (pending.isEmpty && settled.isEmpty)
                const SliverToBoxAdapter(child: _NoRequestsYet())
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  sliver: SliverList.separated(
                    itemCount: pending.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _RequestCard(request: pending[i]),
                  ),
                ),
                if (pending.isEmpty)
                  const SliverToBoxAdapter(child: _AllCaughtUp()),
                if (settled.isNotEmpty) ...[
                  const _Heading(label: 'ANSWERED'),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                    sliver: SliverList.separated(
                      itemCount: settled.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) =>
                          _RequestCard(request: settled[i], muted: true),
                    ),
                  ),
                ],
              ],

              const _Heading(label: 'YOUR PAGE'),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  child: Column(
                    children: [
                      _ManageRow(
                        icon: Icons.badge_outlined,
                        title: 'Public profile',
                        subtitle: 'Headline, about, languages, and your rate',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdvisorProfileEditorScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _ManageRow(
                        icon: Icons.map_outlined,
                        title: 'Travels',
                        subtitle:
                            '${workspace.shownPlaces.length} of ${workspace.places.length} shown on your profile',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdvisorTravelsScreen(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  final AdvisorWorkspace workspace;
  const _Identity({required this.workspace});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: Row(
        children: [
          MonogramAvatar(name: workspace.name, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(workspace.name, style: AppText.display(22)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      workspace.city == null ? Icons.public_rounded : Icons.place_rounded,
                      size: 12,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        workspace.city?.label ?? 'All-around',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.label(11, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _ApprovedChip(),
        ],
      ),
    );
  }
}

class _ApprovedChip extends StatelessWidget {
  const _ApprovedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.verified_rounded, size: 12, color: AppColors.accent),
          const SizedBox(width: 5),
          Text('APPROVED', style: AppText.label(9, color: AppColors.accent)),
        ],
      ),
    );
  }
}

class _Numbers extends StatelessWidget {
  final AdvisorWorkspace workspace;
  const _Numbers({required this.workspace});

  @override
  Widget build(BuildContext context) {
    final accepted =
        workspace.requests.where((r) => r.state == RequestState.accepted).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
      child: Row(
        children: [
          _Number(
            value: '${workspace.pendingRequestCount}',
            label: 'WAITING ON YOU',
            accent: workspace.pendingRequestCount > 0,
          ),
          Container(width: 1, height: 30, color: AppColors.hairline),
          _Number(value: '$accepted', label: 'IN PROGRESS'),
          Container(width: 1, height: 30, color: AppColors.hairline),
          _Number(value: '\$${workspace.pricePerPlan}', label: 'YOUR RATE'),
        ],
      ),
    );
  }
}

class _Number extends StatelessWidget {
  final String value;
  final String label;
  final bool accent;
  const _Number({required this.value, required this.label, this.accent = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppText.display(24, color: accent ? AppColors.accent : null)),
          const SizedBox(height: 5),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.label(9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  final String label;
  final String? trailing;
  const _Heading({required this.label, this.trailing});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 30, 22, 12),
        child: Row(
          children: [
            Text(label, style: AppText.label(11, color: AppColors.textMuted)),
            if (trailing != null) ...[
              const Spacer(),
              Text(trailing!, style: AppText.label(10, color: AppColors.accent)),
            ],
          ],
        ),
      ),
    );
  }
}

/// A traveller's request. The message is the part that decides whether an
/// advisor takes it, so it gets room rather than being trimmed to a chip.
class _RequestCard extends StatelessWidget {
  final PlanRequest request;
  final bool muted;
  const _RequestCard({required this.request, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => RequestSheet.show(context, request),
      child: Opacity(
        opacity: muted ? 0.6 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: request.state == RequestState.pending
                  ? AppColors.accent.withValues(alpha: 0.22)
                  : AppColors.hairline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MonogramAvatar(name: request.travellerName, size: 34, radius: 11),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.travellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(15, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${request.destination.label} · ${request.nights} nights',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.label(10, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _StateTag(state: request.state, daysAgo: request.daysAgo),
                ],
              ),
              const SizedBox(height: 13),
              Text(
                request.message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(13, color: AppColors.textSecondary).copyWith(height: 1.45),
              ),
              const SizedBox(height: 13),
              Row(
                children: [
                  _Meta(
                    icon: Icons.calendar_today_rounded,
                    text: shortRange(request.start, request.end),
                  ),
                  const SizedBox(width: 14),
                  _Meta(
                    icon: Icons.group_outlined,
                    text: '${request.partySize}',
                  ),
                  const Spacer(),
                  Text(
                    '${money(request.budget.toDouble(), request.currency)} budget',
                    style: AppText.label(10, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppColors.textMuted),
        const SizedBox(width: 5),
        Text(text, style: AppText.label(10, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _StateTag extends StatelessWidget {
  final RequestState state;
  final int daysAgo;
  const _StateTag({required this.state, required this.daysAgo});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state) {
      RequestState.pending => (daysAgo == 1 ? '1d ago' : '${daysAgo}d ago', AppColors.textMuted),
      RequestState.accepted => ('ACCEPTED', AppColors.accent),
      RequestState.declined => ('DECLINED', AppColors.textMuted),
    };
    return Text(label, style: AppText.label(9, color: color));
  }
}

class _AllCaughtUp extends StatelessWidget {
  const _AllCaughtUp();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Nothing waiting on you. New requests land here.',
                style: AppText.body(13, color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoRequestsYet extends StatelessWidget {
  const _NoRequestsYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 10, 28, 0),
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, size: 34, color: AppColors.textMuted),
          const SizedBox(height: 14),
          Text('No requests yet', style: AppText.display(19)),
          const SizedBox(height: 8),
          Text(
            'Travellers find you through the advisor list. A fuller profile and '
            'more travels give them more reason to pick you.',
            textAlign: TextAlign.center,
            style: AppText.body(13, color: AppColors.textSecondary).copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _ManageRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ManageRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Row(
          children: [
            Icon(icon, size: 19, color: AppColors.accent),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.body(15, weight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: AppText.label(10, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
