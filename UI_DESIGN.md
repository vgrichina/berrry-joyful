# berrry-joyful UI Design (2026 - Current Implementation)

## Design Philosophy

- **Permissions First**: Show permissions screen immediately on launch if not granted
- **Controls Front & Center**: Tabbed interface focuses on control configuration
- **Logs Secondary**: Debug logs hidden in a collapsible panel
- **Clear Visual Feedback**: Show connection status, active mode, battery level
- **Accessibility**: Large buttons, clear labels, keyboard shortcuts
- **Native macOS**: Uses system colors, fonts, and spacing for perfect light/dark mode support
- **System Settings Style**: macOS System Settings inspired design with horizontal rows, iOS-style switches, and subtle section backgrounds (January 2026 redesign)

---

## Design System

### Colors (Adaptive)
All colors use NSColor semantic system colors for automatic light/dark mode:

```swift
// Backgrounds
NSColor.windowBackgroundColor       // Main background
NSColor.controlBackgroundColor      // Section boxes
NSColor.underPageBackgroundColor    // Tertiary

// Text
NSColor.labelColor                  // Primary text
NSColor.secondaryLabelColor         // Secondary text
NSColor.tertiaryLabelColor          // Tertiary text

// Status Colors
NSColor.systemGreen                 // Success/Connected
NSColor.systemOrange                // Warning
NSColor.systemRed                   // Error
NSColor.systemBlue                  // Info
```

### Typography
Based on SF Pro system font:

- **Display Large**: 20pt Bold (window titles)
- **Headline Medium**: 14pt Semibold (section titles)
- **Body Medium**: 12pt Regular (labels, text)
- **Caption**: 10pt Regular (hints, info text)
- **Code Medium**: 11pt Monospace (debug log)

### Spacing (8pt Grid)
- xxs: 4pt
- xs: 8pt
- sm: 12pt
- md: 16pt
- lg: 24pt
- xl: 32pt

### Visual Elements (System Settings Style - Updated Jan 2026)
- **Corner Radius**: 6pt for section boxes (reduced from 12pt)
- **Section Backgrounds**: Barely visible at 4% opacity (was shadow-based)
- **Borders**: None (minimal design)
- **Section Boxes**: Minimal rounded corners, subtle backgrounds, no shadows
- **Horizontal Rows**: Labels on left (150px width), controls on right (180px width)
- **Switches**: iOS-style NSSwitch instead of checkboxes for toggles
- **Consistent Heights**: 32px rows for all controls (sliders, popups, switches)

---

## Screen 1: First Launch - Permissions Screen

```
┌──────────────────────────────────────────────────────────────────┐
│                        🎮 berrry-joyful                          │
│                   Welcome to Joy-Con Mac Control                 │
└──────────────────────────────────────────────────────────────────┘

  To use berrry-joyful, we need a few permissions:


  ┌────────────────────────────────────────────────────────────┐
  │  🖱️  Accessibility Access                                   │
  │                                                             │
  │  Required to control your mouse and keyboard with Joy-Con  │
  │  controllers. This allows button presses to simulate       │
  │  clicks and stick movements to move your cursor.           │
  │                                                             │
  │  Status: ⚠️  Not Granted                      [ GRANT ]    │
  └────────────────────────────────────────────────────────────┘

  ┌────────────────────────────────────────────────────────────┐
  │  🎤  Voice Input                                            │
  │                                                             │
  │  Optional. Enables voice input where you can speak to type │
  │  text. Requires both Microphone and Speech Recognition     │
  │  permissions. Hold ZL+ZR on your Joy-Con to activate.      │
  │  You can enable this later.                                │
  │                                                             │
  │  Status: ⏸️  Not Requested          [ SKIP ]  [ GRANT ]   │
  └────────────────────────────────────────────────────────────┘

                      [    Continue    ]

  💡 Tip: Click "Grant" to open System Settings. Enable
      berrry-joyful in the Accessibility section, then return here.
```

**Size**: 700x600px (minimum)
**Style**: Clean, centered layout with card-style permission boxes

---

## Screen 2: Main Window - No Controller Connected

```
┌────────────────────────────────────────────────────────────────┐
│ ┌───────┬──────────┬───────┐                                   │
│ │ Mouse │ Keyboard │ Voice │  ← Tabs                           │
│ └───────┴──────────┴───────┴───────────────────────────────────│
│                                                                 │
│   🔍  No Joy-Con detected                                      │
│                                                                 │
│   Please connect your Joy-Con controller via Bluetooth         │
│                                                                 │
│   [  Need Help?  ]                                             │
│                                                                 │
│   Supported: Joy-Con L/R, Pro Controller                       │
│                                                                 │
│                                                                 │
│                                                                 │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ 🔍 No Joy-Con detected          Battery: --      [ ▶ Debug Log ]│
└─────────────────────────────────────────────────────────────────┘
```

**Layout**: 800x700px (resizable, min 700x600)
**Header**: Bottom bar with connection status and debug log toggle
**Content**: Scrollable tab content area
**Help Button**: Appears when no controller connected

---

## Screen 3: Main Window - Controller Connected

### Mouse Tab (Active)

```
┌────────────────────────────────────────────────────────────────┐
│ ┌─ Mouse ─┬──────────┬───────┐                                 │
│ │         │ Keyboard │ Voice │                                 │
│ └─────────┴──────────┴───────┴─────────────────────────────────│
│                                                                 │
│  ╭─ Movement ──────────────────────────────────────────────╮   │
│  │  Sensitivity        ├──────●───────────┤  1.5x        │   │
│  │  Scroll Speed       ├────●─────────────┤  3.0x        │   │
│  │  Invert Y-Axis                            ⎚ ON         │   │
│  │  Acceleration                             ⎚ OFF        │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
│  ╭─ Deadzone ──────────────────────────────────────────────╮   │
│  │  Left Stick         ├───●──────────────┤  15%         │   │
│  │  Right Stick        ├──●───────────────┤  10%         │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
│  ╭─ Stick Functions ───────────────────────────────────────╮   │
│  │  Left Stick         [ Mouse          ▼ ]              │   │
│  │  Right Stick        [ Scroll         ▼ ]              │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
│  ╭─ Sticky Mouse ──────────────────────────────────────────╮   │
│  │  Enable Sticky Mouse                      ⎚ ON         │   │
│  │  Strength           [ Medium         ▼ ]              │   │
│  │  Show Visual Overlay                      ⎚ ON         │   │
│  │                                                          │   │
│  │  ℹ️ Slows cursor near buttons and text fields, making   │   │
│  │     them easier to click. Toggle with L, adjust with    │   │
│  │     ZL+X.                                                │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Connected: Joy-Con (L)       🔋 ---%  🔵 LED 1  [▶ Debug Log]│
└─────────────────────────────────────────────────────────────────┘
```

**Key Features (Updated Jan 2026 - System Settings Style)**:
- Vertical scrolling for content
- Section boxes with subtle backgrounds (4% opacity), no shadows
- Horizontal row layout: label left, control right
- Sliders show live values (1.5x, 15%, etc.)
- iOS-style NSSwitch toggles (⎚) instead of checkboxes
- Popups aligned to right (180px width)
- Info text with emoji icons
- All controls respond instantly (auto-save)
- Minimal 6pt corner radius on sections

---

### Keyboard Tab (Updated Jan 2026 - System Settings Style)

```
┌────────────────────────────────────────────────────────────────┐
│ ┌─────────┬ Keyboard ┬───────┐                                 │
│ │  Mouse  │          │ Voice │                                 │
│ └─────────┴──────────┴───────┴─────────────────────────────────│
│                                                                 │
│  ╭─ Profile ───────────────────────────────────────────────╮   │
│  │  Button Profile     [ Default          ▼ ]             │   │
│  │  [Reset] [Clone]                                        │   │
│  │  Default button mappings for general use                │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
│  ╭─ Button Mapping ────────────────────────────────────────╮   │
│  │  ┌─ Face Buttons ─────────────────────────────────┐   │    │
│  │  │ A Button        Enter                 [ Edit ] │   │    │
│  │  │ B Button        Escape                [ Edit ] │   │    │
│  │  │ X Button        Tab                   [ Edit ] │   │    │
│  │  │ Y Button        Space                 [ Edit ] │   │    │
│  │  └────────────────────────────────────────────────┘   │    │
│  │                                                        │    │
│  │  ┌─ D-Pad ────────────────────────────────────────┐   │    │
│  │  │ Up              ↑                     [ Edit ] │   │    │
│  │  │ Right           →                     [ Edit ] │   │    │
│  │  │ Down            ↓                     [ Edit ] │   │    │
│  │  │ Left            ←                     [ Edit ] │   │    │
│  │  └────────────────────────────────────────────────┘   │    │
│  │                                                        │    │
│  │  ┌─ Triggers & Bumpers ──────────────────────────┐   │    │
│  │  │ ZL Trigger      Command (⌘)          [ Edit ] │   │    │
│  │  │ ZR Trigger      (None)               [ Edit ] │   │    │
│  │  │ ZL+ZR Combo     Voice Input          [ Edit ] │   │    │
│  │  └────────────────────────────────────────────────┘   │    │
│  │                                                        │    │
│  │  [... more buttons ...]                                │    │
│  │                                                        │    │
│  ╰────────────────────────────────────────────────────────╯    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Connected: Joy-Con (L)       🔋 ---%  🔵 LED 1  [▶ Debug Log]│
└─────────────────────────────────────────────────────────────────┘
```

**Key Features (Updated Jan 2026 - System Settings Style)**:
- Scrollable button mapping list (21 mappable buttons) in its own section
- Profile selection in separate section with horizontal row layout
- Profile system (Default, Gaming, Media, Classic)
- Edit button opens key capture window
- Reset and Clone buttons in horizontal layout
- Section headers group related buttons
- Quick profile switch: Minus + D-Pad
- Subtle section backgrounds (4% opacity), minimal styling

---

### Voice Tab

```
┌────────────────────────────────────────────────────────────────┐
│ ┌─────────┬──────────┬ Voice ┐                                 │
│ │  Mouse  │ Keyboard │       │                                 │
│ └─────────┴──────────┴───────┴─────────────────────────────────│
│                                                                 │
│  ╭─ Permissions ───────────────────────────────────────────╮   │
│  │                                                          │   │
│  │  ✅ Permissions Granted                                  │   │
│  │                                                          │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
│  ╭─ Settings ──────────────────────────────────────────────╮   │
│  │  Language           [ English (US)      ▼ ]            │   │
│  │  Status                                  ⏸️ Ready       │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
│  ╭─ How to Use ────────────────────────────────────────────╮   │
│  │                                                          │   │
│  │  1. Hold ZL + ZR on your Joy-Con to activate voice      │   │
│  │     input                                                │   │
│  │                                                          │   │
│  │  2. Speak naturally in your selected language           │   │
│  │                                                          │   │
│  │  3. Release ZL + ZR to type your words automatically    │   │
│  │                                                          │   │
│  │                                                          │   │
│  │  ℹ️ Voice input converts your speech to text and types  │   │
│  │     it automatically. Perfect for hands-free typing!    │   │
│  │                                                          │   │
│  ╰──────────────────────────────────────────────────────────╯   │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Connected: Joy-Con (L)       🔋 ---%  🔵 LED 1  [▶ Debug Log]│
└─────────────────────────────────────────────────────────────────┘
```

**Key Features (Updated Jan 2026 - System Settings Style)**:
- Permission status clearly shown in section
- Language selection with horizontal row layout (label left, dropdown right)
- Status row with label on left, value on right
- Step-by-step instructions in "How to Use" section
- Info text explaining the feature
- Grant button if permissions not granted
- Minimal section styling with subtle backgrounds

---

## Screen 4: Debug Log (Expanded)

```
┌────────────────────────────────────────────────────────────────┐
│ [Tab content area - compressed vertically]                     │
├─────────────────────────────────────────────────────────────────┤
│ ▼ Debug Log                                                     │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ [12:34:56] 🫐 berrry-joyful initialized - waiting...       │ │
│ │ [12:34:58] ✅ Controller Connected: Joy-Con (L)            │ │
│ │ [12:34:58] 🎮 JoyConSwift monitoring started               │ │
│ │ [12:35:12] 🕹️ A → Enter                                    │ │
│ │ [12:35:15] 📍 Left stick: x=0.45, y=-0.23                  │ │
│ │ [12:35:15] 🖱️ Mouse moved: dx=6.8, dy=-3.5                 │ │
│ │                                                             │ │
│ └─────────────────────────────────────────────────────────────┘ │
├─────────────────────────────────────────────────────────────────┤
│ ✅ Connected: Joy-Con (L)       🔋 ---%  🔵 LED 1  [▼ Debug Log]│
└─────────────────────────────────────────────────────────────────┘
```

**Animation**: 0.25s ease-in-out when toggling
**Height**: 200px when expanded
**Features**:
- Monospace font (SF Mono 11pt)
- Timestamps on each line
- Emoji indicators for event types
- Auto-scrolls to latest message
- Dark background for contrast

---

## Screen 5: Connection Help Dialog

```
┌────────────────────────────────────────────────────────────────┐
│ ℹ️  How to Connect Joy-Con Controllers                         │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ 1. Open System Settings → Bluetooth                            │
│                                                                 │
│ 2. Put Joy-Con in pairing mode:                                │
│    • Hold the small sync button (on the rail)                  │
│    • LED will start flashing                                   │
│                                                                 │
│ 3. Click Connect when Joy-Con appears in Bluetooth list        │
│                                                                 │
│ 4. Return to berrry-joyful - controller will be detected       │
│    automatically                                                │
│                                                                 │
│ Supported Controllers:                                          │
│ • Joy-Con (L) - Left controller                                │
│ • Joy-Con (R) - Right controller                               │
│ • Nintendo Pro Controller                                      │
│                                                                 │
│ Note: Both Joy-Cons can be connected simultaneously for        │
│ full control.                                                   │
│                                                                 │
│                   [    OK    ]  [ Open Bluetooth Settings ]    │
└────────────────────────────────────────────────────────────────┘
```

**Trigger**: Click "Need Help?" button or Help → Controller Setup Guide
**Style**: Standard NSAlert with informational icon

---

## Screen 6: About Window

```
┌────────────────────────────────────────────────────────────────┐
│ ℹ️  Berrry Joyful                                               │
├────────────────────────────────────────────────────────────────┤
│                                                                 │
│ Version 1.0.3 (Build 10)                                       │
│                                                                 │
│ Control your Mac with Nintendo Joy-Con controllers.            │
│ Perfect for Claude Code, terminal workflows, and accessibility.│
│                                                                 │
│ © 2025 Berrry Computer                                         │
│                                                                 │
│ This app uses JoyConSwift by magicien (MIT License)            │
│                                                                 │
│ GitHub: github.com/vgrichina/berrry-joyful                     │
│ Privacy: No data collection, fully offline                     │
│                                                                 │
│                        [    OK    ]  [ View on GitHub ]        │
└────────────────────────────────────────────────────────────────┘
```

**Trigger**: Menu → Berrry Joyful → About Berrry Joyful
**Features**: Version info, credits, privacy notice, GitHub link

---

## Menu Bar Structure

```
Berrry Joyful
  About Berrry Joyful
  ─────────────────
  Quit Berrry Joyful          ⌘Q

View
  Show Help                   /

Debug (DEBUG BUILDS ONLY)
  Start Drift Logging
  Stop Drift Logging
  ─────────────────
  Show Drift Statistics
  Open Logs Folder

Help
  Berrry Joyful Help          ?
  Controller Setup Guide
  ─────────────────
  Report Issue...
  Berrry Joyful on GitHub
```

---

## Key Interactions

### Controller Connection
1. App starts → Monitor for Joy-Con via JoyConSwift
2. Controller connected → Update header, show battery/LED
3. No controller → Show "Need Help?" button
4. Help button → Show connection instructions dialog

### Settings Changes
- **Mouse sliders**: Auto-save on change, show live value
- **Keyboard Edit**: Opens modal window with button capture
- **Profile switching**: Dropdown OR Minus + D-Pad combo
- **Voice language**: Dropdown auto-saves

### Mode Switching
- **ZL+ZR**: Voice input mode (shows "🎤 Listening..." overlay)
- **L+R+X**: (Future: Help overlay)
- **Minus + D-Pad**: Quick profile switch (shows profile overlay)

### Debug Log
- Collapsed by default
- Toggle with button → Smooth 0.25s animation
- Shows all controller events, system messages
- Auto-scrolls to bottom

---

## Design Notes

### AppKit Integration
- Pure AppKit (no SwiftUI)
- Programmatic layout (no storyboards/XIBs)
- FlippedView for top-down coordinates
- NSTabView for tabs
- NSSplitView for debug log
- NSStackView for section layouts

### Visual Hierarchy
1. **Primary**: Section box titles (14pt semibold)
2. **Secondary**: Control labels (12pt regular)
3. **Tertiary**: Info text (10pt caption)
4. **Code**: Debug log (11pt monospace)

### Responsive Design
- Minimum size: 700x600px
- Sliders grow/shrink with window width
- Section boxes have max width
- Keyboard tab scrolls vertically
- All tabs support vertical scrolling

### Accessibility
- All controls have accessibility labels
- Keyboard navigation supported
- High contrast compatible
- VoiceOver compatible
- Dynamic Type supported (system fonts)

### Polish (Updated Jan 2026 - System Settings Style)
- Smooth animations (0.25s ease-in-out)
- Barely visible section backgrounds (4% opacity)
- Minimal rounded corners (6pt, reduced from 12pt)
- No shadows (removed for minimal design)
- 8pt grid spacing
- Horizontal row layouts (label left, control right)
- iOS-style switches instead of checkboxes
- Proper autoresizing masks
- Native macOS System Settings feel

---

## Implementation Priority

### Phase 1: ✅ Complete
- Permissions screen
- Main window with tabs
- Mouse configuration
- Keyboard configuration
- Voice configuration
- Debug log
- Connection help

### Phase 2: ✅ Complete
- Profile system
- Button mapping editor
- Sticky mouse feature
- Design system
- Section boxes with subtle backgrounds (updated Jan 2026)

### Phase 3: ✅ Complete
- About window
- Help menu
- Connection guide
- Auto-save settings

### Phase 4: Future Enhancements
- Profile overlay with cheat sheet
- Visual controller state indicator
- Onboarding tutorial
- Advanced animations
- More profiles

---

## Version History

- **v1.0.0** (Jan 2025): Initial release
- **v1.0.1**: Added sticky mouse, profile system
- **v1.0.2**: Design system, section boxes
- **v1.0.3**: Profile overlay, quick switching
- **v1.0.4** (Jan 2026): System Settings style redesign - horizontal rows, iOS switches, minimal backgrounds
- **Current**: All core features complete with modern UI
