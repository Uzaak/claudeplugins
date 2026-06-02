---
name: running-flutter-app-in-simulator
description: >
  Use when you need to run a Flutter app in an iOS simulator — launching, monitoring logs,
  applying code changes via hot reload or hot restart, and diagnosing startup errors.
  Provides access to live Flutter logs, which are essential for verifying UI changes and
  catching runtime errors autonomously.
---

# Running a Flutter App in the iOS Simulator

## Why this matters

Running the app gives you access to the Flutter log stream — the ground truth for whether the app started, what errors occurred, and what exceptions are firing. Never claim a change worked without confirming via the log.

## Step 1 — Verify the simulator is booted

```bash
xcrun simctl list devices | grep Booted
```

If nothing is listed, boot it and open the GUI:

```bash
xcrun simctl boot <UDID>
open -a Simulator
```

> **Important:** The Simulator runtime and the Simulator.app GUI are independent processes. The runtime can be running while the window is closed. Check both:
> - Runtime: `xcrun simctl list devices | grep Booted`
> - GUI window: `ps aux | grep "Simulator.app" | grep -v grep`

To find available UDIDs:

```bash
xcrun simctl list devices available | grep -E "iPhone|iPad" | grep -v unavailable
```

## Step 2 — Kill any stale flutter process

```bash
PID=$(ps aux | grep 'flutter_tools.snapshot run' | grep -v grep | awk '{print $2}' | head -1)
[ -n "$PID" ] && kill "$PID" && sleep 2
```

## Step 3 — Launch in the background with a log file

```bash
LOG=/tmp/flutter.log
echo "=== Launched at $(date) ===" > "$LOG"
flutter run -d <UDID> >> "$LOG" 2>&1 &
```

Replace `<UDID>` with the target simulator's UDID (from Step 1). All stdout and stderr go to `$LOG`.

## Step 4 — Wait for the ready signal (no sleeping)

```bash
until grep -q "Flutter run key commands\|Error\|Exception" "$LOG"; do sleep 3; done
tail -30 "$LOG"
```

**Success:** `Flutter run key commands` — app is live and attached.  
**Failure:** `Error` or `Exception` — read the full log and fix before continuing.

Cold start: 20–60 s first build, 3–10 s on subsequent runs.

## Step 5 — Apply code changes without restarting

After editing source files, signal the running flutter process:

```bash
PID=$(ps aux | grep 'flutter_tools.snapshot run' | grep -v grep | awk '{print $2}' | head -1)

# Hot reload — preserves app state (for UI tweaks)
kill -SIGUSR1 "$PID"

# Hot restart — resets app state (for logic/DI/state changes)
kill -SIGUSR2 "$PID"
```

**Always run `flutter analyze --no-pub` before signaling.** Hot-reloading broken code can crash the Dart VM, requiring a full relaunch:

```bash
flutter analyze --no-pub && kill -SIGUSR1 "$PID"
```

After reloading, take a screenshot to confirm the UI updated.

## Reading the logs

| Log content | Meaning |
|---|---|
| `Flutter run key commands` | App is up and attached |
| `Reloaded N of M libraries` | Hot reload succeeded |
| `Restarted application` | Hot restart succeeded |
| `Error` / `Exception` | Runtime failure — read surrounding lines |

## Troubleshooting

**"No supported devices found"** — Simulator isn't booted. Run Step 1.

**Simulator.app not visible** — Runtime may be up but GUI is closed. Run `open -a Simulator`.

**Flutter process keeps dying** — Check `flutter analyze` for compile errors before retrying.
