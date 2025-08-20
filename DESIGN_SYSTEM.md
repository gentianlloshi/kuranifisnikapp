# Design System Overview

This document summarizes the design system foundations and implementation details for the Kurani Fisnik app (Design System 2.x lineage).

## 1. Tokens
**Location:** `lib/presentation/theme/design_tokens.dart`

Tokens are grouped by category:
- Spacing: `spaceXs, spaceSm, spaceMd, spaceLg, spaceXl, space2xl` exposed via `BuildContext` extensions for ergonomic access (`context.spaceMd`).
- Radii: Consistent rounded corners (4, 8, 10, 12, Stadium) used for surfaces, chips, sheets.
- Palette Families:
  - Sepia (reading focus / light warm)
  - Deep (cool / balanced light)
  - Dark (minimal dark neutral base)
- Semantic Material ColorScheme values built from palette constants.
- Overlays (dark mode tonal elevation helpers): `darkOverlayLow`, `darkOverlayMed`, `darkOverlayHigh`.

## 2. Elevation & Tonal Layering
**Extension:** `ColorScheme.surfaceElevated(level)` in `theme.dart`.

Goal: Provide material-like depth without heavy drop shadows, relying on subtle tonal shifts.

Levels (guidelines):
- 0: Base surface (`scheme.surface`) or transparent; use for full-screen backgrounds.
- 1: Containers/cards resting directly above base lists (bookmark cards, search results, surah header bar).
- 2: Nested emphasis blocks (note containers, active selection backgrounds, mini player, highlighted verse container in dark if needed).
- 3: Floating elements inside sheets or high-emphasis interactive regions (filter chips sheet, active memorization step panel).
- 4: Highest local elevation inside bottom sheets or transient surfaces (rare; reserved for future dialogs/tooltips if needed).

Implementation (dark): Blends overlay tints progressively onto `surface` (approx additive alpha ramp). In light mode we often reuse `surface` or `surfaceVariant` but standardized via `surfaceElevated` to centralize control.

Tinting Pattern: When contextual accent is needed (e.g., note container), we alpha-blend a low-opacity `primary` onto the elevated base instead of choosing a hard-coded color.

## 3. Sheets
Unified via `BottomSheetWrapper` + `SheetHeader` (`sheet_header.dart`).
- Consistent padding using spacing tokens.
- Optional leading/back button + title & trailing actions.
- Background uses an elevated surface (typically level 2-3 in dark, 1 in light) ensuring contrast with underlying content.

## 4. Word & Verse Highlighting
- Per-word highlight uses animated containers; glow enabled in light mode for focus, softened in dark mode.
- Verse selection highlight adapts opacity based on brightness to prevent bloom in dark mode.
- Dark mode adjustments lower alpha and introduce subtle shadow for readability without harsh borders.

## 5. Color Usage Guidelines
- Avoid direct use of `surfaceVariant` in widgets; prefer `surfaceElevated(level)` for depth consistency.
- Use `onSurfaceVariant` for muted iconography / secondary labels when inside elevated surfaces.
- For chips or small tags: `primary.withOpacity(0.10-0.20)` over an elevated surface; ensure sufficient contrast for label text (`onPrimaryContainer` or `onSurface` depending on background luminance calculation if introduced later).

## 6. Typography
- Base Material text theme; weight adjustments for emphasis (600 for tag labels, title mediums).
- Avoid custom font sizes inline; rely on theme text styles (e.g., `bodySmall`, `labelMedium`).

## 7. Spacing Rhythm
- Vertical stacks: prefer 4/8/12/16 px increments via tokens.
- List item vertical margin: `spaceMd` to `spaceLg` depending on density.
- Inside cards: outer padding `spaceLg`; internal element separation `spaceSm`.

## 8. Adaptive Behavior
- Dark mode surfaces: escalate level for contained accents (e.g., note container uses level 2) to differentiate layers.
- Light mode may keep lower level (1) and rely on subtle accent tint.
- Auto-scroll & audio highlight respects user interaction—suspends when user manually scrolls (see logic in Quran view widget).

## 9. Component Migration Checklist
When creating/updating a component:
1. Replace raw paddings with spacing tokens.
2. Replace direct surface/surfaceVariant with `surfaceElevated(level)`.
3. Blend accent color using low-opacity `primary` if contextual emphasis is needed.
4. Use `SheetHeader` for any modal/bottom sheets.
5. Ensure dark mode contrast (check text legibility at WCAG ~AA where feasible).
6. Remove duplicated styling constants; centralize in tokens or theme.

## 10. Pending / Future Work
- Formal contrast tests & golden snapshots for elevation layers.
- Possible semantic roles for levels (e.g., `surfaceCard`, `surfaceAccent`) if proliferation increases.
- i18n centralization of strings currently inline (e.g., bookmark labels, dialog texts).
- Incremental search index improvements & multi-surah queue (outside pure design scope).

## 11. Naming Convention
Version tag format: "Design system X.Y" where:
- X increments on structural or token model changes.
- Y increments on rollout/polish waves (e.g., applying elevation to more components, dark adjustments).

## 12. Rationale Summary
Consistent tonal elevation reduces visual noise versus ad-hoc color choices and ensures dark mode remains comfortable for long reading sessions while preserving hierarchy.

---
Last updated: 2025-08-20 (Design system 2.8)
