# Project Instructions for Antigravity — Lycri (Lyric Presentation App)

## Read This First

Read this entire file before writing a single line of code. Return to it at the start of every session. It is the source of truth for architecture, structure, and the style system. When in doubt, check here before making assumptions.

---

## What You Are Building

**Lycri** is a desktop lyric presentation app for **macOS** (with Windows to follow later as a separate project). The operator uses a main control window to manage and style song lyrics, then sends them to a full-screen presentation view on a second connected display — similar in concept to ProPresenter or EasyWorship but focused, lean, and reliable.

The app must be smooth and stable above all else. It will be used in live settings (churches, events) where a crash or stutter is unacceptable.

---

## Core User Flows

1. Operator types or pastes lyrics into the main window
2. Operator styles the lyrics (font, size, color, alignment, background)
3. Operator pushes the current slide to the connected second display
4. Presentation screen shows the lyrics full-screen, live
5. Operator updates slides in real time; presentation updates reactively

---

## Tech Stack

| Concern | Tool |
|---|---|
| Framework | Flutter (Desktop) |
| Language | Dart |
| State Management | Riverpod |
| Local Database | Drift (SQLite) |
| Backend & Auth | Supabase *(scaffold the structure now, activate later)* |
| Multi-display | `screen_retriever` + `window_manager` |
| Font Loading | `google_fonts` |
| File Handling | `file_picker` |
| Style System | Custom token files (see Style System section) |

---

## Project Structure

Maintain this exactly. Do not reorganize without flagging it first.

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
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── models/
│   │
│   ├── presentation_screen/         # Second display output window
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── models/
│   │
│   ├── style_editor/                # Lyric styling panel
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── models/
│   │
│   ├── library/                     # Song/lyric library
│   │   ├── presentation/
│   │   ├── providers/
│   │   └── models/
│   │
│   └── auth/                        # Supabase auth (scaffold only for now)
│       ├── presentation/
│       ├── providers/
│       └── models/
│
└── shared/
    ├── widgets/
    └── providers/
```

---

## Architecture Pattern

**Feature-First Clean Architecture with Riverpod.**

- Each feature owns its UI, providers, and models
- Features never import each other's internals — they communicate through shared providers only
- Business logic lives in Riverpod notifiers, never in widgets
- Widgets read state and dispatch actions only — they contain no logic

### Multi-Window Strategy

Two Flutter windows run simultaneously:

- **Main Window** — Operator control panel, always on the primary display
- **Presentation Window** — Lyric output, targeted to the second connected screen, borderless and full-screen, no OS chrome

Both windows share state via Riverpod. When the operator updates the active slide, the shared provider updates and the Presentation Window rebuilds reactively.

```dart
// Shared provider both windows subscribe to
final activeSlideProvider = StateNotifierProvider<ActiveSlideNotifier, SlideState>((ref) {
  return ActiveSlideNotifier();
});
```

The Presentation Window should not be closeable by the user directly — only controlled from the operator window.

### Multi-Display Implementation

```dart
// Detect screens and position Presentation Window on secondary display
final screens = await ScreenRetriever.instance.getAllDisplays();
final secondaryScreen = screens.length > 1 ? screens[1] : null;

if (secondaryScreen != null) {
  await windowManager.setPosition(
    Offset(secondaryScreen.visiblePosition!.dx, secondaryScreen.visiblePosition!.dy)
  );
}
```

This is the most technically critical feature. Implement and test it early. If a limitation is hit, flag it immediately.

---

## Style System — This Is Critical

The style system is a **first-class concern**. All visual values must come from the token files. Never hardcode a color, font size, spacing value, border radius, or stroke width inline in a widget.

When a Figma design is shared, match it precisely. If a token for a new value doesn't exist yet, create it in the appropriate token file first, then use it.

---

### COLORS — `core/theme/app_colors.dart`

The design uses a **light theme** (white/gray surfaces, dark text). The brand color is **Orange**.

#### Primitive Palette (Brand Colors)

```dart
// Orange scale
static const Color orange0    = Color(0xFFFFF8F5);
static const Color orange50   = Color(0xFFFDEEE1);
static const Color orange100  = Color(0xFFFFD9CA);
static const Color orange200  = Color(0xFFFFAE8F);
static const Color orange300  = Color(0xFFFF824C);
static const Color orange400  = Color(0xFFFF6200);   // Brand primary
static const Color orange500  = Color(0xFFC54A00);
static const Color orange600  = Color(0xFF9D3900);
static const Color orange700  = Color(0xFF762A00);
static const Color orange800  = Color(0xFF521B00);
static const Color orange900  = Color(0xFF310D00);
static const Color orange950  = Color(0xFF210700);
static const Color orange1000 = Color(0xFF130300);

// Gray scale
static const Color gray0    = Color(0xFFFFFFFF);
static const Color gray50   = Color(0xFFEFEEEE);
static const Color gray100  = Color(0xFFDEDDDD);
static const Color gray200  = Color(0xFFBFBDBD);
static const Color gray300  = Color(0xFF9F9D9D);
static const Color gray400  = Color(0xFF827F7E);
static const Color gray500  = Color(0xFF666261);
static const Color gray600  = Color(0xFF4B4747);
static const Color gray700  = Color(0xFF312D2B);
static const Color gray800  = Color(0xFF191513);
static const Color gray900  = Color(0xFF0E0A08);
static const Color gray950  = Color(0xFF050302);
static const Color gray1000 = Color(0xFF000000);
```

#### Semantic Theme Tokens (use these in widgets)

```dart
// Text
static const Color textBold    = gray1000;
static const Color textSubtle  = gray500;
static const Color textMinimal = gray200;
static const Color textInverse = gray0;
static const Color textSuccess = Color(0xFF00A600);
static const Color textDanger  = Color(0xFFDC0000);
static const Color textWarning = Color(0xFFA37A00);
static const Color textBrand   = orange400;
static const Color textLink    = orange1000;

// Surfaces (light theme — lightest to darkest)
static const Color surface4          = gray0;
static const Color surface3          = gray50;
static const Color surface2          = gray100;
static const Color surface1          = gray200;
static const Color surface0          = gray300;
static const Color surfaceBrand      = orange400;
static const Color surfaceInverse    = gray1000;
static const Color surfaceBrandLight = orange50;

// Semantic surfaces
static const Color surfaceDanger        = Color(0xFFBA0000);
static const Color surfaceDangerLight   = Color(0xFFFFE4E4);
static const Color surfaceSuccess       = Color(0xFF008A00);
static const Color surfaceSuccessLight  = Color(0xFFD5FFD5);
static const Color surfaceWarning       = Color(0xFFA37A00);
static const Color surfaceWarningLight  = Color(0xFFFFFADB);

// Borders
static const Color borderBold    = gray200;
static const Color borderSubtle  = gray100;
static const Color borderMinimal = gray50;
static const Color borderFocused = orange300;
static const Color borderHover   = orange100;
static const Color borderBrand   = orange400;
static const Color borderInverse = gray0;

// Button states (brand)
static const Color btnBrandPrimaryRest     = orange400;
static const Color btnBrandPrimaryHover    = orange600;
static const Color btnBrandPrimaryPressed  = orange800;
static const Color btnBrandPrimaryDisabled = gray300;

// Icons
static const Color iconBold    = gray900;
static const Color iconSubtle  = gray500;
static const Color iconMinimal = gray200;
static const Color iconInverse = gray0;
static const Color iconBrand   = orange400;

// Presentation screen (full-screen display output)
static const Color presentationBackground = gray1000;
static const Color presentationText       = gray0;
```

---

### TYPOGRAPHY — `core/theme/app_typography.dart`

The design uses **two typefaces**:
- **Libre Caslon Condensed** — All headings, titles, display, buttons, UI labels
- **Libre Caslon Text** — All body/paragraph text
- **Source Code Pro** — Code blocks only (rarely used in the UI)

All fonts must be loaded via `google_fonts`. Verify both Libre Caslon variants are available before using them.

```dart
// Font family constants
static const String fontDisplay = 'Libre Caslon Condensed';
static const String fontBody    = 'Libre Caslon Text';
static const String fontCode    = 'Source Code Pro';

// ─── Display ─────────────────────────────────────────────────────────────────
static const TextStyle displayLg = TextStyle(
  fontFamily: fontDisplay, fontSize: 83, fontWeight: FontWeight.w600,
  letterSpacing: -2.49, height: 88 / 83,
);
static const TextStyle displayMd = TextStyle(
  fontFamily: fontDisplay, fontSize: 67, fontWeight: FontWeight.w600,
  letterSpacing: -2.01, height: 72 / 67,
);
static const TextStyle displaySm = TextStyle(
  fontFamily: fontDisplay, fontSize: 53, fontWeight: FontWeight.w600,
  letterSpacing: -1.59, height: 56 / 53,
);

// ─── Heading ──────────────────────────────────────────────────────────────────
static const TextStyle headingLg = TextStyle(
  fontFamily: fontDisplay, fontSize: 43, fontWeight: FontWeight.w600,
  letterSpacing: -1.29, height: 48 / 43,
);
static const TextStyle headingMd = TextStyle(
  fontFamily: fontDisplay, fontSize: 34, fontWeight: FontWeight.w600,
  letterSpacing: -1.02, height: 40 / 34,
);
static const TextStyle headingSm = TextStyle(
  fontFamily: fontDisplay, fontSize: 27, fontWeight: FontWeight.w600,
  letterSpacing: -0.81, height: 32 / 27,
);

// ─── Title ────────────────────────────────────────────────────────────────────
static const TextStyle titleLg = TextStyle(
  fontFamily: fontDisplay, fontSize: 22, fontWeight: FontWeight.w600,
  letterSpacing: -0.66, height: 28 / 22,
);
static const TextStyle titleMd = TextStyle(
  fontFamily: fontDisplay, fontSize: 17, fontWeight: FontWeight.w600,
  letterSpacing: -0.51, height: 24 / 17,
);
static const TextStyle titleSm = TextStyle(
  fontFamily: fontDisplay, fontSize: 14, fontWeight: FontWeight.w600,
  letterSpacing: -0.42, height: 20 / 14,
);

// ─── Body ─────────────────────────────────────────────────────────────────────
static const TextStyle bodyLg = TextStyle(
  fontFamily: fontBody, fontSize: 16, fontWeight: FontWeight.w400,
  letterSpacing: -0.32, height: 24 / 16,
);
static const TextStyle bodyLgBold = TextStyle(
  fontFamily: fontBody, fontSize: 16, fontWeight: FontWeight.w500,
  letterSpacing: -0.32, height: 24 / 16,
);
static const TextStyle bodyMd = TextStyle(
  fontFamily: fontBody, fontSize: 14, fontWeight: FontWeight.w400,
  letterSpacing: -0.28, height: 20 / 14,
);
static const TextStyle bodyMdBold = TextStyle(
  fontFamily: fontBody, fontSize: 14, fontWeight: FontWeight.w600,
  letterSpacing: -0.28, height: 20 / 14,
);
static const TextStyle bodySm = TextStyle(
  fontFamily: fontBody, fontSize: 11, fontWeight: FontWeight.w400,
  letterSpacing: -0.22, height: 12 / 11,
);
static const TextStyle bodySmBold = TextStyle(
  fontFamily: fontBody, fontSize: 11, fontWeight: FontWeight.w600,
  letterSpacing: -0.22, height: 12 / 11,
);

// ─── Buttons ──────────────────────────────────────────────────────────────────
// Apply TextCapitalization.words on the widget for capitalize case
static const TextStyle btnLg = TextStyle(
  fontFamily: fontDisplay, fontSize: 18, fontWeight: FontWeight.w700,
  letterSpacing: -0.36, height: 20 / 18,
);
static const TextStyle btnSm = TextStyle(
  fontFamily: fontDisplay, fontSize: 10, fontWeight: FontWeight.w600,
  letterSpacing: -0.20, height: 16 / 10,
);

// ─── Link ─────────────────────────────────────────────────────────────────────
static const TextStyle link = TextStyle(
  fontFamily: fontDisplay, fontSize: 17, fontWeight: FontWeight.w600,
  letterSpacing: -0.51, height: 24 / 17,
  decoration: TextDecoration.underline,
);
```

---

### SPACING — `core/theme/app_spacing.dart`

Exact values from Figma's `_Units` collection.

```dart
class AppSpacing {
  static const double none   = 0;
  static const double u3xs   = 0.5;
  static const double u2xs   = 1;
  static const double xs     = 2;
  static const double sm     = 4;
  static const double md     = 8;
  static const double xmd    = 12;
  static const double lg     = 16;
  static const double xl     = 24;
  static const double x2l    = 32;
  static const double x3l    = 40;
  static const double x4l    = 48;
  static const double x5l    = 56;
  static const double x6l    = 64;
  static const double x7l    = 128;
  static const double x8l    = 152;
  static const double x9l    = 256;

  // Named layout aliases
  static const double mgnDesktop = x8l;  // 152 — desktop page margin
  static const double mgnMisc    = 23;   // misc1 value
}
```

---

### BORDER RADIUS — `core/theme/app_radius.dart`

```dart
class AppRadius {
  static const double none = 0;    // rad-null
  static const double xs   = 2;    // rad-xs
  static const double sm   = 4;    // rad-sm
  static const double md   = 8;    // rad-md
  static const double lg   = 16;   // rad-lg
  static const double xl   = 24;   // rad-xl
  static const double full = 100000; // rad-rd — fully rounded (pills, circles)
}
```

---

### STROKE WIDTHS — `core/theme/app_stroke.dart`

```dart
class AppStroke {
  static const double sm = 0.5;  // stroke-sm
  static const double md = 1.0;  // stroke-md
  static const double lg = 2.0;  // stroke-lg
  static const double xl = 4.0;  // stroke-xl
}
```

---

## Key Data Models

### `LyricSlide`
```dart
class LyricSlide {
  final String id;
  final String text;
  final LyricStyle style;
}
```

### `LyricStyle`
Holds all runtime-configurable visual properties for the presentation display. Defaults reference token values.
```dart
class LyricStyle {
  final String fontFamily;           // default: AppTypography.fontDisplay
  final double fontSize;             // user-adjustable, default: 52
  final FontWeight fontWeight;
  final Color textColor;             // default: AppColors.presentationText
  final TextAlign alignment;
  final Color? backgroundColor;      // default: AppColors.presentationBackground
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

## Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # Database
  drift: ^2.18.0
  sqlite3_flutter_libs: ^0.5.0

  # Backend (scaffold now, activate later)
  supabase_flutter: ^2.5.0
  flutter_dotenv: ^5.1.0

  # Windowing & display
  window_manager: ^0.3.9
  screen_retriever: ^0.1.9

  # Fonts
  google_fonts: ^6.2.1

  # File handling
  file_picker: ^8.0.3

dev_dependencies:
  build_runner: ^2.4.9
  riverpod_generator: ^2.4.0
  drift_dev: ^2.18.0
```

---

## Build Order for This First Session

This session is about **understanding the project and getting the structure ready**. Do not build features yet.

1. **Flutter desktop project** — Create the project with macOS desktop support enabled
2. **Install all dependencies** — Every package in pubspec.yaml above
3. **Folder structure** — Create all directories from the Project Structure section, with `.gitkeep` placeholders where needed
4. **Token files** — Create all five token files with the exact values from this document
5. **`app_theme.dart`** — Assemble a basic `ThemeData` from tokens. Surface = `AppColors.surface4`, background = `AppColors.surface0`, primary = `AppColors.orange400`
6. **`main.dart`** — Initialize `window_manager`, then call `runApp()`
7. **`app.dart`** — Root widget with theme applied. Confirm it runs without errors
8. **Font verification** — Render a small test widget showing one line in `Libre Caslon Condensed` and one in `Libre Caslon Text` to confirm both load correctly

When all of the above is done and the app runs clean, this session is complete. Report back with confirmation.

---

## Supabase (Scaffold Only — Do Not Implement Auth Yet)

Set up the initialization so it's ready for when auth is needed. Do not build login UI.

```dart
// In main.dart, before runApp():
await Supabase.initialize(
  url: const String.fromEnvironment('SUPABASE_URL'),
  anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY'),
);
```

Store credentials in `.env`. Never hardcode them. Add `.env` to `.gitignore`.

---

## General Rules

- **Never hardcode** a color, spacing value, font size, radius, or stroke width. Always reference a token.
- **No logic in widgets.** Logic belongs in Riverpod notifiers only.
- **Figma screenshots override everything.** When a design is shared, match it exactly. Ask for measurements if anything is unclear.
- **Flag blockers early.** If a package limitation or Flutter desktop constraint is discovered, surface it before working around it silently.
- **Keep `main.dart` minimal.** Initialization and `runApp()` only.
- **Comment non-obvious code**, especially multi-window and display management code.
- **Auth is scaffolded but not active.** Don't build login UI. Just ensure the Supabase init doesn't cause errors.

---

## Context

Lycri will be used in live settings — churches, events, worship nights. The operator cannot afford a crash or stutter mid-service. Build defensively. Smooth rendering on the presentation screen is the core product promise.

The Figma design files are the visual source of truth. When designs are shared, they override any assumptions made in this document.
