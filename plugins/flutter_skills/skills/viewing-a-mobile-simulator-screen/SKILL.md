---
name: viewing-a-mobile-simulator-screen
description: >
  Use when you need to see what is currently displayed on an iOS simulator screen —
  taking a screenshot and reading it to understand the current UI state, verify a
  change landed correctly, identify element positions, or detect error dialogs.
---

# Viewing a Mobile Simulator Screen

## Taking the screenshot

```bash
xcrun simctl io booted screenshot /tmp/screen.png
```

Then read it with the Read tool — the image renders visually in the response.

Use `booted` to target whichever simulator is currently running. If multiple simulators are booted simultaneously, target by UDID instead:

```bash
xcrun simctl io <UDID> screenshot /tmp/screen.png
```

## Coordinate system

iOS simulator screenshots are **3× retina** on modern iPhones (e.g., iPhone 16: **1179×2556 px** at 3×, **393×852 logical points**). When you need element coordinates for tapping, divide pixel values by the scale factor:

```
logical_x = pixel_x / 3
logical_y = pixel_y / 3
```

Always work in **logical points** for tap coordinates — that's what the interaction APIs expect.

## What to look for

**Verify a change landed:** Take a screenshot after hot reload or hot restart. If the UI matches your expectation, the change is live. If it still shows the old state, the reload may have failed — check the log.

**Detect a crash or blank screen:** A completely gray or black screen with no app content means the app crashed or never finished launching. Check the Flutter log for exceptions.

**Locate interactive elements:** Read element positions in pixels from the screenshot, then convert to logical points for tapping. Buttons, dialogs, and input fields are all identifiable this way.

**Spot system dialogs:** Permission prompts (notifications, camera, etc.) appear as system-level overlays and block the app UI. Identify the button position and tap to dismiss before interacting with the app.

**Debug banner:** A red "DEBUG" banner in the top-right corner is normal in debug builds.

## Workflow

```
edit code → hot reload → screenshot → read image → confirm or diagnose
```

Never claim a UI change worked without taking a screenshot. The log confirms the reload succeeded; the screenshot confirms what the user actually sees.
