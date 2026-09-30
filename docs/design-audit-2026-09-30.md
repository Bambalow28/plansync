# PlanSync design audit — 2026-09-30

Code-level audit (Flutter, adaptive → iOS reference). Scores are out of 4.

| Dimension | Score | Key finding |
|---|---|---|
| Accessibility | 2 | Icon-only buttons had no VoiceOver label; gradient CTAs were not announced as buttons; 81 text styles under the 11pt floor; no Reduce Motion handling |
| Performance | 3 | Lists are virtualized; photos cached. Startup awaits 6 services before the first frame |
| Appearance & theming | 2 | Tokens exist in `AppColors`/`AppText`, but 130 `Colors.white/black` and 23 raw `Color(0x…)` sit outside the theme. Dark only, by design |
| Platform conformance | 3 | Material widgets on iOS (AlertDialog, popup menus) but swipe-back and Switch.adaptive are right; 105 Material icons instead of SF Symbols-style |
| Adaptivity | 2 | Phone layouts only: no iPad/landscape treatment, no text-scale stress pass |
| **Total** | **12/20** | Acceptable — significant work needed |

## Fixed in this pass
- Type floor: `AppText` raises anything under 11pt to 11pt (mono captions, badges).
- Tooltips (VoiceOver labels) on the icon-only buttons: back, edit, delete, share, month prev/next, traveller stepper, settings.
- `Semantics(button: true)` on the main gradient CTAs (Save, New Trip) and the advisor pill.
- Advisor pill and Settings gear now have a 44pt hit area.
- `EntranceFade` honours Reduce Motion.

## Backlog (not done)
1. Replace the 130 `Colors.white/black` with tokens (`AppColors.onAccent`, text alphas) — P2.
2. Semantics/tooltips on the remaining ~40 `GestureDetector` taps that hold icons only — P2.
3. Text-scale pass at 200%: fixed-height chips and the day selector will clip — P2.
4. iPad / landscape layout (max content width, two-column trip detail) — P2.
5. Startup: don't block first frame on Unsplash warm-up, advisor workspace and Live Activity init — P3.
6. Contrast: `textMuted` (35% white) on `surface` is below 4.5:1 — raise to ~55% for any text that carries meaning — P1.
