---
description: How to use AXe CLI to interact with iOS Simulator for UI testing and automation
---

# AXe iOS Simulator Automation Workflow

AXe is a CLI tool for interacting with iOS Simulators using Apple's Private Accessibility APIs. Use this workflow to test UI changes live in the simulator.

## Prerequisites

- AXe CLI installed via Homebrew: `brew install cameroncooke/axe/axe`
- iOS Simulator running (boot from Xcode or `xcrun simctl boot <UDID>`)

## Getting Started

### 1. List Available Simulators

```bash
axe list-simulators
```

This shows all simulators with their UDIDs. Pick a booted simulator to work with.

### 2. Set Simulator UDID

Store the UDID for easier command usage:

```bash
UDID="<paste-udid-here>"
```

---

## Standard Testing Initialization

**CRITICAL**: Before testing any feature, you must navigate through the authentication and onboarding screens to reach the main app. Follow these steps in order:

### Step 1: Auth Screen - Continue with Apple

When the app launches, it shows the auth screen. Click the "Continue with Apple" button:

```bash
# Option 1: Tap by label (preferred)
axe tap --label "Continue with Apple" --udid $UDID

# Option 2: Tap by coordinates (if label fails)
# The button is typically in the lower portion of the screen
axe tap -x 238 -y 890 --udid $UDID
```

**Wait briefly** for authentication to complete (add a post-delay):

```bash
axe tap --label "Continue with Apple" --post-delay 2.0 --udid $UDID
```

### Step 2: Onboarding - Skip

After authentication, the onboarding screen appears showing "Welcome to Syllabus Sync". Click the "Skip" button:

```bash
# Tap "Skip" button
axe tap --label "Skip" --udid $UDID
```

### Step 3: Final Setup - Get Started

The final onboarding screen "Ready to Get Started?" appears. Click "Get Started":

```bash
# Tap "Get Started" button
axe tap --label "Get Started" --udid $UDID
```

### Complete Initialization Sequence

Here's the full automation sequence to get from app launch to the Dashboard:

```bash
# Set your UDID first
UDID="<your-simulator-udid>"

# 1. Continue with Apple (with 2 second wait)
axe tap --label "Continue with Apple" --post-delay 2.0 --udid $UDID

# 2. Skip onboarding (with 1 second wait)
axe tap --label "Skip" --post-delay 1.0 --udid $UDID

# 3. Get Started (with 1 second wait)
axe tap --label "Get Started" --post-delay 1.0 --udid $UDID

# 4. You should now be on the Dashboard - verify with screenshot
axe screenshot --output dashboard-ready.png --udid $UDID
```

**Now you're ready to test!** The app is at the Dashboard and you can begin testing whatever feature changes were made.

---

## Common Commands

### Taking Screenshots

```bash
# Auto-generated filename
axe screenshot --udid $UDID

# Save to specific path
axe screenshot --output ~/Desktop/screenshot.png --udid $UDID
```

### Describing UI (Accessibility Tree)

```bash
# Full screen UI hierarchy
axe describe-ui --udid $UDID

# Specific point
axe describe-ui --point 100,200 --udid $UDID
```

This is extremely useful for understanding what UI elements are on screen and their accessibility identifiers.

### Tapping Elements

```bash
# Tap at coordinates
axe tap -x 100 -y 200 --udid $UDID

# Tap by accessibility identifier (preferred)
axe tap --id "loginButton" --udid $UDID

# Tap by accessibility label
axe tap --label "Sign In" --udid $UDID
```

### Typing Text

```bash
# Type text (use single quotes for special characters)
axe type 'Hello World!' --udid $UDID

# From stdin (best for automation)
echo "test@example.com" | axe type --stdin --udid $UDID
```

### Gestures

```bash
# Scroll gestures
axe gesture scroll-up --udid $UDID
axe gesture scroll-down --udid $UDID

# Swipe from edges (navigation)
axe gesture swipe-from-left-edge --udid $UDID  # Back navigation

# Custom swipe
axe swipe --start-x 100 --start-y 300 --end-x 300 --end-y 100 --udid $UDID
```

### Hardware Buttons

```bash
axe button home --udid $UDID
axe button lock --udid $UDID
axe button siri --udid $UDID
```

### With Timing Controls

```bash
# Add delays before/after actions
axe tap -x 100 -y 200 --pre-delay 1.0 --post-delay 0.5 --udid $UDID
axe gesture scroll-down --pre-delay 0.5 --post-delay 1.0 --udid $UDID
```

---

## Recording & Streaming

### Record Video

```bash
# Record to MP4 (press Ctrl+C to stop)
axe record-video --udid $UDID --fps 15 --output recording.mp4
```

### Stream Video

```bash
# Stream MJPEG
axe stream-video --udid $UDID --fps 10 --format mjpeg > stream.mjpeg
```

---

## Testing Workflow Example

When testing a UI change in Syllabus Sync:

1. **Boot simulator and run app from Xcode**
2. **Get UDID**: `axe list-simulators` (find the booted simulator)
3. **Set UDID variable**: `UDID="<paste-udid>"`
4. **Complete initialization sequence** (see "Standard Testing Initialization" section above):
   - Tap "Continue with Apple"
   - Tap "Skip"
   - Tap "Get Started"
   - Wait for Dashboard to load
5. **Navigate to the feature being tested** (e.g., Reminders, Calendar, Settings)
6. **Capture baseline screenshot**: `axe screenshot --output before.png --udid $UDID`
7. **Describe current UI** (optional): `axe describe-ui --udid $UDID`
8. **Interact with the feature**: Tap buttons, type text, scroll, etc.
9. **Capture result screenshot**: `axe screenshot --output after.png --udid $UDID`
10. **Verify changes worked** by reviewing screenshots or UI description

**Example: Testing RemindersView Changes**

```bash
# After completing initialization to reach Dashboard:

# Navigate to Reminders tab (bottom navigation)
axe tap --label "Reminders" --udid $UDID
axe screenshot --output reminders-view.png --udid $UDID

# Test your changes here...
# e.g., tap a reminder, scroll, filter courses, etc.
```

---

## Tips

- Always use `--id` or `--label` for tapping when possible (more reliable than coordinates)
- Use `describe-ui` to find accessibility identifiers for elements
- Add proper `accessibilityIdentifier` to SwiftUI views for reliable automation
- Screenshots are saved as PNG files
- Video recordings are H.264 encoded MP4 files

## Reference

- GitHub: https://github.com/cameroncooke/AXe
- Run `axe --help` or `axe <command> --help` for detailed options
