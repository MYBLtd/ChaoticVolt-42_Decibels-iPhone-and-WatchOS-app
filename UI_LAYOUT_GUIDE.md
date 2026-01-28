# UI Layout Changes - Shield Status

## Before (1 Row)
```
┌────────────────────────────────────────────────────────────────┐
│  🛡️ Shield Status                                    ● Live    │
├────────────────────────────────────────────────────────────────┤
│  ┌────────┐  ┌────────┐  ┌──────────┐  ┌───────────┐         │
│  │  🔇    │  │  📊    │  │   🔊     │  │    📈     │         │
│  │  Mute  │  │  Duck  │  │ Loudness │  │ Normalize │         │
│  └────────┘  └────────┘  └──────────┘  └───────────┘         │
└────────────────────────────────────────────────────────────────┘
```

## After (2 Rows) ⭐
```
┌────────────────────────────────────────────────────────────────┐
│  🛡️ Shield Status                                    ● Live    │
├────────────────────────────────────────────────────────────────┤
│  Row 1: Core Audio Controls                                    │
│  ┌────────┐  ┌────────┐  ┌──────────┐  ┌───────────┐         │
│  │  🔇    │  │  📊    │  │   🔊     │  │    📈     │         │
│  │  Mute  │  │  Duck  │  │ Loudness │  │ Normalize │         │
│  └────────┘  └────────┘  └──────────┘  └───────────┘         │
│                                                                 │
│  Row 2: DSP Processing  ⭐ NEW                                 │
│  ┌────────┐  ┌────────────┐                                   │
│  │  ↗️    │  │     🔍     │                                   │
│  │ Bypass │  │ Bass boost │     [empty]     [empty]           │
│  └────────┘  └────────────┘                                   │
└────────────────────────────────────────────────────────────────┘
```

## Detailed Status - Now Collapsed by Default ⭐

### Before (Expanded by default)
```
┌────────────────────────────────────────────────────────────────┐
│  ℹ️ Detailed Status                                       ▼   │
├────────────────────────────────────────────────────────────────┤
│  🔊 Quantum Flavor        │  ✅ Last Contact                   │
│     FULL                  │     Just now                       │
│                                                                 │
│  🔉 System Volume                                              │
│     80%                                                         │
│     ⚠️ Normalizer reducing ~20%                                │
│     ✅ Safe headroom active                                    │
│                                                                 │
│  ⚡ Energy Core                        ████████████████  100%  │
└────────────────────────────────────────────────────────────────┘
```

### After (Collapsed by default)
```
┌────────────────────────────────────────────────────────────────┐
│  ℹ️ Detailed Status                                       ▶   │ ⭐
└────────────────────────────────────────────────────────────────┘
   (tap to expand)
```

## Shield Status Icon & Color Reference

### Row 1: Core Audio Controls
| Shield | Icon | Color | Function |
|--------|------|-------|----------|
| **Mute** | `speaker.slash.fill` | 🔴 Red | Silence audio output |
| **Duck** | `waveform.path.badge.minus` | 🟠 Orange | Reduce volume by −12 dB |
| **Loudness** | `speaker.wave.3` | 🔵 Blue | Low-volume frequency compensation |
| **Normalize** | `waveform.path.ecg` | 🟢 Green | Dynamic range compression |

### Row 2: DSP Processing ⭐ NEW
| Shield | Icon | Color | Function |
|--------|------|-------|----------|
| **Bypass** | `arrow.triangle.turn.up.right.circle` | 🟣 Purple | Bypass EQ processing |
| **Bass boost** | `waveform.badge.magnifyingglass` | 🟣 Indigo | Enhanced bass response |

## State Visualization

### Active State
```
┌──────────────┐
│   ↗️  (icon) │  ← Icon in active color
│   Bypass     │  ← Text in active color
└──────────────┘
  Purple border
  Purple background (15% opacity)
```

### Inactive State
```
┌ ─ ─ ─ ─ ─ ─ ┐
│   ↗️  (icon) │  ← Icon in gray
│   Bypass     │  ← Text in gray
└ ─ ─ ─ ─ ─ ─ ┘
  Gray border (30% opacity)
  Clear background
```

## Interaction Flow

```
User taps "Bypass" pill
       ↓
Haptic feedback (light impact)
       ↓
Visual press animation (scale 0.98)
       ↓
BLE command sent: [0x08, 0x01]
       ↓
Device processes command
       ↓
GalacticStatus notification received
       ↓
UI updates (bit 4 checked)
       ↓
Pill shows active state (purple)
```

## Layout Properties

### Spacing
- Between rows: 12pt
- Between pills: 12pt
- Internal padding: 8pt vertical

### Sizing
- Pills: Equal width (maxWidth: .infinity)
- Height: Content-based (icon + text + padding)
- Corner radius: 8pt

### Grid Structure
```
HStack(spacing: 12) {
    Pill1  Pill2  Pill3  Pill4
}
↓
HStack(spacing: 12) {
    Pill5  Pill6  Empty  Empty
}
```

### Responsive Behavior
- Pills expand equally to fill available width
- On smaller screens (iPhone SE), text may wrap
- Icons remain fixed size
- Minimum tap target: 44×44pt (iOS HIG compliant)

## Accessibility

- ✅ VoiceOver labels: "Bypass, button, off" / "Bypass, button, on"
- ✅ Semantic colors with sufficient contrast
- ✅ Haptic feedback for state changes
- ✅ Info buttons with detailed descriptions
- ✅ Dynamic Type support (scales with text size)

## Animation

- State changes: `easeInOut(duration: 0.1)`
- Press effect: `scale(0.98)` with 0.1s duration
- Expansion/collapse: SwiftUI's default DisclosureGroup animation
- Live indicator: Smooth fade in/out with `.transition(.opacity)`
