---
name: clicking-on-a-mobile-simulator-screen
description: >
  Use when you need to interact with an iOS simulator by tapping buttons, dismissing
  dialogs, navigating between screens, or triggering UI actions — without requiring
  the user to touch the screen manually.
---

# Clicking on a Mobile Simulator Screen

## Tool: idb (Facebook iOS Debug Bridge)

`idb` sends tap events to the simulator in logical point coordinates.

## Setup — start the companion process

The `idb_companion` daemon must be running before you can send taps:

```bash
idb_companion --udid <UDID> --only simulator &
sleep 2
idb connect <UDID>
```

Run this once per session. If `idb` isn't on PATH, check common locations:
- `/opt/homebrew/bin/idb_companion` (Homebrew)
- `~/.local/bin/idb_companion` (symlink)
- Python site-packages: `python3 -m pip show fb-idb` to find it

## Sending a tap

```bash
idb ui tap <x_logical> <y_logical>
```

Coordinates are in **logical points**, not pixels.

## Converting screenshot pixels → logical points

Screenshots are 3× retina on modern iPhones. Divide by the display scale:

```
logical_x = pixel_x / 3
logical_y = pixel_y / 3
```

Example: a button whose center is at pixel (540, 1800) → tap at logical (180, 600).

**iPhone 16 reference:** 1179×2556 px screenshot → 393×852 pt logical screen.

## Workflow

```
screenshot → read image → locate element center in pixels → divide by 3 → tap → screenshot
```

Always take a screenshot after tapping to confirm the action had the intended effect. If the UI didn't change, the tap coordinates may be off — re-examine the screenshot and adjust.

## Tips

- **Dialogs block the app** — permission prompts (notifications, camera, etc.) must be tapped first before the app UI is reachable.
- **Scroll position matters** — if an element is below the fold it won't be tappable. Scroll first or use a screenshot to confirm it's in frame.
- **Retina scale varies** — iPhone SE / older devices may be 2× (divide by 2). Check device specs if coordinates are consistently off.
- **After tapping, verify** — take a screenshot and confirm the screen changed as expected before proceeding with the next step.
