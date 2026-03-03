---
name: lycri-project
description: >
  Best practices and architectural rules for building Lycri — a Flutter desktop
  lyric presentation app for macOS. Use this skill whenever working on any part
  of the Lycri codebase: adding features, editing styles, writing widgets,
  managing state, or touching any project file. This skill is the source of
  truth for architecture, structure, naming, and the design token system.
compatibility: Flutter (Desktop), Dart, Riverpod, Drift, Supabase (scaffold), macOS
metadata:
  version: "1.0"
  project: lycri-lyrics
---

# Lycri Project — Best Practices & Architecture Rules

## What Lycri Is

Lycri is a **macOS desktop lyric presentation app** built in Flutter. An operator uses a main control window to manage and style song lyrics, then pushes them to a full-screen output on a second connected display. It is used live — churches, events, worship nights — so **stability and rendering smoothness are the core product promise**. A crash or stutter mid-service is unacceptable.

---

## When to Use This Skill

Read and follow this skill whenever you are:

- Adding or modifying any widget, provider, model, or token file
- Styling any UI element whatsoever
- Building a new feature or screen
- Configuring windowing or multi-display behavior
- Touching `main.dart`, `app.dart`, or any theme file
- Wiring up Riverpod state or data models

---

## Rule 1 — Project Structure Is Fixed

Maintain this structure exactly. Do not reorganize without flagging it first.

```
lib/
├── main.dart                        # Init only: window_manager, then runApp()
├── app.dart                         # Root widget, router
│
├── core/
│   ├── theme/
│   │   ├── app_colors.dart          # Brand + semantic color tokens
│   │   ├── app_typography.dart      # All TextStyle definitions
│   │   ├── app_spacing.dart         # Spacing + distance constants
│   │   ├── app_radius.dart          # Border radius constants
│   │   ├── app_stroke.dart          # Stroke/border width constants
│   │   └── app_theme.dart           # Assembles ThemeData from tokens
│   ├── constants/
│   └── utils/
│
├── features/
│   ├── operator/                    # Main control window
│   ├── presentation_screen/         # Second display output
│   ├── style_editor/                # Lyric styling panel
│   ├── library/                     # Song/lyric library
│   └── auth/                        # Supabase auth (scaffold only)
│
└── shared/
    ├── widgets/
    └── providers/
```

Each feature contains: `presentation/`, `providers/`, `models/`

---

## Rule 2 — The Design Token System Is Non-Negotiable

**Never hardcode a color, spacing value, font size, border radius, or stroke width inline in a widget.** Every visual value must come from the token files in `core/theme/`.

### How to Apply Tokens

| What you need         | Where to get it                                |
| --------------------- | ---------------------------------------------- |
| Color                 | `AppColors.xxx` from `app_colors.dart`         |
| Text style            | `AppTypography.xxx` from `app_typography.dart` |
| Spacing / padding     | `AppSpacing.xxx` from `app_spacing.dart`       |
| Border radius         | `AppRadius.xxx` from `app_radius.dart`         |
| Stroke / border width | `AppStroke.xxx` from `app_stroke.dart`         |

### Adding New Token Values

If a Figma design uses a value that doesn't have a token yet:

1. Create the token in the appropriate file first
2. Name it clearly and consistently with existing tokens
3. Only then use it in the widget

### Use Semantic Tokens, Not Primitives

```dart
// ✅ Correct — semantic token
Text('Hello', style: TextStyle(color: AppColors.textBold));

// ❌ Wrong — hardcoded
Text('Hello', style: TextStyle(color: Color(0xFF000000)));

// ❌ Wrong — primitive instead of semantic
Text('Hello', style: TextStyle(color: AppColors.gray1000));
```

### Key Token Reference

**Colors** — always use semantic names:

- Text: `textBold`, `textSubtle`, `textMinimal`, `textInverse`, `textBrand`, `textSuccess`, `textDanger`
- Surfaces (light, lightest → darkest): `surface4` → `surface3` → `surface2` → `surface1` → `surface0`
- Borders: `borderBold`, `borderSubtle`, `borderMinimal`, `borderFocused`, `borderBrand`
- Icons: `iconBold`, `iconSubtle`, `iconBrand`
- Presentation screen: `presentationBackground` (black), `presentationText` (white)
- Buttons (brand): `btnBrandPrimaryRest`, `btnBrandPrimaryHover`, `btnBrandPrimaryPressed`, `btnBrandPrimaryDisabled`

**Typography** — two typefaces, both registered as local assets in `assets/fonts/`:

- `Libre Caslon Condensed` → headings, titles, display, buttons, UI labels → `AppTypography.displayXx`, `headingXx`, `titleXx`, `btnXx`, `link`
- `Libre Caslon Text` → body/paragraph text → `AppTypography.bodyXx`
- `Source Code Pro` → code blocks only

**Spacing** — use `AppSpacing.xxx` constants:
`sm = 4`, `md = 8`, `xmd = 12`, `lg = 16`, `xl = 24`, `x2l = 32`, `x3l = 40` ...

**Radius** — `AppRadius.xs = 2`, `sm = 4`, `md = 8`, `lg = 16`, `xl = 24`, `full = 100000`

**Stroke** — `AppStroke.sm = 0.5`, `md = 1.0`, `lg = 2.0`, `xl = 4.0`

---

## Rule 3 — Architecture Is Feature-First Clean

- Each feature (`operator`, `presentation_screen`, `style_editor`, `library`, `auth`) owns its UI, providers, and models
- **Features never import each other's internals** — they communicate through `shared/providers/` only
- **No logic in widgets** — business logic belongs in Riverpod notifiers only
- Widgets read state and dispatch actions only — they contain no logic

```dart
// ✅ Correct — widget reads from provider, dispatches actions
class LyricSlideCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slide = ref.watch(activeSlideProvider);
    return GestureDetector(
      onTap: () => ref.read(activeSlideProvider.notifier).push(slide),
      child: Text(slide.text),
    );
  }
}

// ❌ Wrong — logic inside a widget
class LyricSlideCard extends StatefulWidget {
  void _handleTap() {
    // business logic does not belong here
  }
}
```

---

## Rule 4 — Multi-Window Strategy

Two Flutter windows run simultaneously:

- **Main Window** — Operator control panel, primary display
- **Presentation Window** — Lyric output, second screen, borderless and full-screen, no OS chrome

Both share state via Riverpod. The active slide is a shared provider that both windows subscribe to. When the operator updates the slide, the Presentation Window rebuilds reactively.

```dart
// Shared provider both windows subscribe to
final activeSlideProvider = StateNotifierProvider<ActiveSlideNotifier, SlideState>((ref) {
  return ActiveSlideNotifier();
});
```

The **Presentation Window must not be closeable** by the user directly — only controlled from the operator window.

### Multi-Display Implementation Pattern

```dart
final screens = await ScreenRetriever.instance.getAllDisplays();
final secondaryScreen = screens.length > 1 ? screens[1] : null;

if (secondaryScreen != null) {
  await windowManager.setPosition(
    Offset(secondaryScreen.visiblePosition!.dx, secondaryScreen.visiblePosition!.dy)
  );
}
```

---

## Rule 5 — `main.dart` Must Stay Minimal

`main.dart` contains only:

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `.env` loading via `flutter_dotenv`
3. `window_manager` initialization and window options
4. Supabase scaffold initialization
5. `runApp()`

No widget code, no business logic, no feature imports.

---

## Rule 6 — Supabase Is Scaffolded, Not Active

Auth is not built yet. Do not create login UI. The Supabase init in `main.dart` must not throw errors, but no auth flows should be implemented until explicitly requested.

Credentials live in `.env` only — never hardcoded, never committed to git.

```dart
await Supabase.initialize(
  url: dotenv.env['SUPABASE_URL'] ?? '',
  anonKey: dotenv.env['SUPABASE_ANON_KEY'] ?? '',
);
```

---

## Rule 7 — Key Data Models

### `LyricSlide`

```dart
class LyricSlide {
  final String id;
  final String text;
  final LyricStyle style;
}
```

### `LyricStyle`

All defaults must reference token values — never hardcode.

```dart
class LyricStyle {
  final String fontFamily;         // default: AppTypography.fontDisplay
  final double fontSize;           // user-adjustable, default: 52
  final FontWeight fontWeight;
  final Color textColor;           // default: AppColors.presentationText
  final TextAlign alignment;
  final Color? backgroundColor;    // default: AppColors.presentationBackground
  final String? backgroundImagePath;
  final double backgroundOpacity;
  final double textShadowBlur;
  final Color? textShadowColor;
  final EdgeInsets padding;
}
```

### `Song`

```dart
class Song {
  final String id;
  final String title;
  final String? artist;
  final List<LyricSlide> slides;
  final DateTime createdAt;
}
```

---

## Rule 8 — Figma Screenshots Override Everything

When a Figma design is shared, match it exactly. Designs take priority over assumptions made in this file. If a measurement is unclear, ask for it — do not guess.

---

## Rule 9 — Comment Non-Obvious Code

Multi-window and display management code must be commented. If it's not immediately obvious _why_ something exists, explain it.

---

## Rule 10 — Flag Blockers Early

If a package limitation or Flutter desktop constraint is discovered, surface it before working around it silently. Do not implement a silent fallback without documenting the issue first.

---

## Quick Checklist Before Committing Any Change

- [ ] All colors reference `AppColors` semantic tokens
- [ ] All spacing uses `AppSpacing` constants
- [ ] All text styles use `AppTypography` definitions
- [ ] All radii use `AppRadius` constants
- [ ] All stroke widths use `AppStroke` constants
- [ ] No logic exists inside a widget's `build()` method
- [ ] No feature imports another feature's internals directly
- [ ] `main.dart` contains only init code
- [ ] No credentials or `.env` values are hardcoded
