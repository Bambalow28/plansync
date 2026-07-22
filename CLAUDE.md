# CLAUDE.md

Standalone Flutter app (unrelated to the sibling projects).

Layout: Dart, `pubspec.yaml`, `lib/`, `test/`.

## No narration before output (READ FIRST)

**Do not explain, narrate, or think out loud before making changes.** No
"let me look at…", no "here's the plan", no step-by-step commentary between
tool calls. Do the work silently (tool calls only), then give the result at the
**end** — nothing before it. This applies to every task, including reviews and
multi-step investigations: gather silently, emit findings only once, at the end.

Exceptions (the ONLY ones): (1) the user explicitly asks for a plan, walkthrough,
or explanation — then give it once, at the end; (2) you are genuinely blocked and
must ask a single clarifying question.

## Finishing a task

Close out with a **minimal response** — no feature tour, no re-explaining the
diff, no restating the plan. One-line summary of what changed, plus only anything
not captured in the diff — a decision needed, a failing test, a caveat, a
follow-up. Nothing else.

## Model delegation (who does the thinking)

Opus is the brain and always owns the final review. For any task, Opus first
analyzes it, then decides where the reasoning happens:

- **Opus reasons inline** when the task is small/contained enough that a handoff
  costs more than just thinking it through.
- **Delegate the thinking + fixing to Sonnet 5** when the task is large,
  multi-file, or token-heavy.
- **Opus always reviews** what Sonnet returns, running both `/code-review`
  (correctness) and `/ponytail-review` (over-engineering) — every time. Sonnet's
  output isn't done until it passes both. If either fails, send it back with
  specific feedback and re-review.

## Small fixes

Typo, one-line fix, minor tweak: make the change, don't narrate, give a one-line
summary at the end. Minimal output tokens.

## Ponytail (active)

The ladder is the default reflex for every code task:
YAGNI → reuse what's in-repo → stdlib → native platform → installed deps → one
line → minimal code. Understand the problem fully first, then take the highest
rung that holds. Bug fix = root cause at the shared function, not per-caller
symptom patches. Mark deliberate corner-cuts with a `ponytail:` comment naming
the ceiling and upgrade path. Non-trivial logic leaves ONE runnable check.

**Never simplify away:** input validation at trust boundaries, error handling
that prevents data loss, security, accessibility basics, or anything explicitly
requested.

## Working in this project

- Analyze/lint: `flutter analyze` (config in `analysis_options.yaml`).
- Test: `flutter test`.
- Format: `dart format`.
- Deps: edit `pubspec.yaml`, then `flutter pub get` — prefer packages already in
  `pubspec.lock` over adding new ones.

## Builds / CI

When the user says "let's do a build" (or equivalent), after finishing the task
at hand: make sure this project's self-hosted GitHub Actions runner is online
before pushing to `main` — that push is what triggers
`.github/workflows/testflight.yml`. Check status, and start it if offline:

```
gh api repos/Bambalow28/plansync/actions/runners --jq '.runners[] | {name,status}'
cd ~/actions-runner-plansync && nohup ./run.sh > run.log 2>&1 & disown
```

Once the triggered workflow run finishes (`gh run list --branch main --limit 1`
shows `completed`), stop the runner rather than leaving it listening:

```
pkill -f 'actions-runner-plansync/bin/Runner.Listener'
```
