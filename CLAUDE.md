# Lycri

Flutter desktop app (macOS + Windows) for presenting song lyrics. Operator window
is a 3-column layout (`lib/features/operator/presentation/`): lyric input |
presenter preview | style editor. Output goes to a presentation window and NDI.

## Design source of truth: Figma Bridge

Designs arrive as exports in `design-sync/` (gitignored) — see the
`figma-bridge` skill for how to read them.

- **Only implement from frame exports** (`design-sync/<frame>/`). The user
  exports the screens to build. `_file-context/thumbs/` and the page list in
  `_file-context/CONTEXT.md` include abandoned design directions — don't
  treat them as specs.
- `_file-context/variables.json` is authoritative for token values.
  `app_colors.dart` is generated from it; if Figma variables change, regenerate
  rather than hand-editing values.

## Token mapping (frame.json → code)

| Figma | Code |
| --- | --- |
| `Text/text-bold`, `Surface/surface-4`, `Button/brand-primary-rest`, … | `AppColors.textBold`, `AppColors.surface4`, `AppColors.btnBrandPrimaryRest` (group prefix dropped for Text/Icon/Surface/Border; `btn`, `badge`, `indicator`, `toggle`, `menu`, `list`, `table`, `textInput` kept) |
| `Orange/Orange400`, `Red/Red500`, … (primitives) | `AppColors.orange400`, `AppColors.red500` — only when the frame binds a primitive directly |
| `dist-*` (gaps / itemSpacing) | `AppSpacing.*` — `dist-md` → `AppSpacing.md` (8) |
| `pad-*` (padding) | `AppPadding.*` — `pad-md` → `AppPadding.md` (12). Scale is offset from `dist-*`; always map by name |
| `rad-*` | `AppRadius.*` (`rad-rd` → `AppRadius.full`) |
| `stroke-*` | `AppStroke.*` |
| Text styles `Title/title-md`, `Body/body-lg`, … | `AppTypography.titleMd`, `AppTypography.bodyLg`, … |

Never hardcode hex/px values when the frame has a token binding.

## Typography

- Advent Pro (Bold 700, Black 900) — display, heading, title, button, link.
- Gabarito (400–700) — body.
- Source Code Pro — code.
- Display / Heading / Title (and button) styles are UPPERCASE in Figma —
  every title, header, dialog/menu heading and label set in them. Flutter has
  no text-case property: call `.toUpperCase()` on those strings. For text
  *fields* in those styles use `CapsTextEditingController`
  (`lib/shared/utils/caps_text_controller.dart`): it shows caps but keeps the
  typed value. Exception: lyric content (preview / output) keeps its case.
- The "Lycri" wordmark uses `AppTypography.logo` (Advent Pro Black 34).
- Libre Caslon fonts stay bundled only as user-selectable lyric fonts (saved
  presets reference them); the UI itself doesn't use them.

## Overflow: fade, never clip

No hard edge clipping or ellipses anywhere in the UI (current and new
screens):

- Single-line text that can overflow → `FadeText`
  (`lib/shared/widgets/fade_text.dart`), never `TextOverflow.ellipsis/clip`.
- Scrollable areas → wrap the scroll view in `ScrollFadeMask`
  (`lib/shared/widgets/scroll_fade_mask.dart`); edges fade only while there
  is more content past them.
- Exception: the audience-facing output (presentation window, NDI view)
  renders lyrics unmasked.

## Database (Drift)

Migrations run only when the app opens the database at startup. After any
schema change (tables, columns, `schemaVersion`) the app must be **fully
restarted** — a hot reload keeps the old connection, and every write that
touches the new column fails until restart.
