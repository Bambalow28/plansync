# CLAUDE.md

Standalone Flutter app (unrelated to the sibling projects).

Layout: Dart, `pubspec.yaml`, `lib/`, `test/`.

## Builds / CI (self-hosted runner)

When the user says "let's do a build" (or equivalent), after finishing the
task at hand: make sure the self-hosted GitHub Actions runner is online
before pushing to `main` — that push triggers `.github/workflows/testflight.yml`.
Check status, start if offline:

```
gh api repos/Bambalow28/plansync/actions/runners --jq '.runners[] | {name,status}'
cd ~/actions-runner-plansync && nohup ./run.sh > run.log 2>&1 & disown
```

Once the triggered run finishes (`gh run list --branch main --limit 1` shows
`completed`), stop the runner:

```
pkill -f 'actions-runner-plansync/bin/Runner.Listener'
```
