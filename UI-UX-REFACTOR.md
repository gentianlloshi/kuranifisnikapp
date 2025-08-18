# Kurani Fisnik – UI/UX Refactor Strategic Plan

Version: 1.0  
Author: Senior Product Design (Devotion to the Content)  
Purpose: Practical, actionable blueprint to elevate the interface from functional Material baseline to a refined, content-first reading & study experience.

---
## 1. Design System Foundation

### 1.1 Philosophy: "Devotion to the Content"
Focus hierarchy: (1) Sacred Arabic text, (2) Translation comprehension, (3) Study utilities (search, thematic, texhvid), (4) Secondary meta (counts, juz, references).

Principles:
- Quiet surfaces, generous whitespace, zero ornamental noise.
- Typography as primary visual identity; color as subtle guide.
- Motion = meaning (no decorative animations).
- Adaptive layout: scale gracefully from narrow phones → large tablets.

### 1.2 Color Palettes (Three Themes)
Pick one as default; others as switchable themes. All accessible (≥4.5:1 for primary text on surfaces).

#### A. Sepia / Gold (Warm Study Default)
| Role | Hex | Notes |
|------|-----|-------|
| Primary | #8A6A33 | Headings, key actions |
| PrimaryContainer | #EEDFC2 | AppBar alt / accent backgrounds |
| Secondary | #C29B5B | Chips, secondary buttons |
| Background | #FAF6EF | App shell |
| Surface | #F4EBDD | Cards, panels |
| SurfaceVariant | #E9DDCC | Section headers |
| Accent / Highlight | #D4AA48 | Active verse highlight, selection |
| Error | #B3261E | Standard error |
| Text Primary | #2E2618 | Body / Arabic translation meta |
| Text Muted | #6A5B44 | Secondary labels |
| Divider | #E2D6C4 | Hairlines |

#### B. Deep Blue / Emerald (Calm Scholarly)
| Role | Hex |
|------|-----|
| Primary | #0E4D47 |
| PrimaryContainer | #D2ECE9 |
| Secondary | #1F6D62 |
| Background | #F6FAFA |
| Surface | #ECF3F2 |
| SurfaceVariant | #DDE8E7 |
| Accent | #2E877D |
| Error | #BA1A1A |
| Text Primary | #102524 |
| Text Muted | #4A6663 |
| Divider | #D3E2E0 |

#### C. Minimal Dark (Refined Night Mode)
| Role | Hex |
|------|-----|
| Primary | #6FBFAF |
| PrimaryContainer | #143530 |
| Secondary | #86D3C4 |
| Background | #0E1514 |
| Surface | #182120 |
| SurfaceVariant | #24302F |
| Accent | #52A896 |
| Error | #FF554D |
| Text Primary | #F2F8F7 |
| Text Muted | #9AB5B0 |
| Divider | #2C3937 |

Highlight Technique: Accent color at 12–18% opacity fill + 3px solid left border (accent) for active verse.

### 1.3 Typography Scale
Arabic Font: Amiri Quran (primary) + Amiri Regular fallback.
Latin (Albanian) Font: Lora (serif) or optional Lato for Compact Mode.

Scaling: Base = 16sp (phones). On width ≥600dp multiply by 1.125; ≥840dp multiply by 1.2 (cap Arabic body at 34sp).

| Token | Size | Line Height | Weight | Usage |
|-------|------|-------------|--------|-------|
| displayLarge | 34 | 1.15 | 700 | Special headers / landing |
| headlineMedium | 24 | 1.25 | 600 | Section titles |
| titleLarge | 20 | 1.30 | 600 | Card headers / dialogs |
| titleMedium | 18 | 1.30 | 600 | List item primary |
| bodyArabic | 26 | 1.65 | 500 | Ayah Arabic text |
| bodyLarge | 16 | 1.55 | 400 | Translation main |
| bodyMedium | 14 | 1.50 | 400 | Supporting text |
| bodySmall | 13 | 1.35 | 500 | Meta line (Surah • Ayah • Juz) |
| labelMedium | 12 | 1.20 | 500 | Chips / small badges |
| actionLabel | 14 | 1.20 | 600 | Buttons / actions |

Arabic Specific:
- letterSpacing: -0.5
- textAlign: Justify (if comfortable) else start
- use height rather than extra padding for rhythm

### 1.4 Iconography
- Material Symbols Outlined variant only (consistency & reduced visual weight).
- Standard sizes: 24 (global), 28 (primary actions), 20 (inline verse actions).
- Color states: Muted (60% text) → Hover/pressed = Primary (100%) → Disabled 30%.

### 1.5 Spacing & Radii Tokens
Spacing scale: 4, 8, 12, 16, 20, 24, 32,  Forty (40) for large blocks.
Common patterns: Vertical rhythm in reading = 4/6/8 micro, 12 between clusters, 20 between verse blocks.
Radii: 4 (chips), 8 (small surfaces), 12 (cards), 16 (modal panels), Stadium (pills/chips/buttons).

### 1.6 Elevation & Surfaces
- Light Mode: Use elevation 0 / 1 / 2 only; reduce shadow color opacity for subtlety.
- Dark Mode: Rely on surface layering + tonal overlays (8–12%) rather than strong shadows.

### 1.7 Theming Implementation Notes
- Create `design_tokens.dart` exposing ColorScheme factories + TextTheme builder.
- Provide `AdaptiveTypographyScaler` using `MediaQuery.size.width` breakpoints.

---
## 2. Component-Based Refactoring Plan

### 2.1 Global Components
**AppBar**
- Default background = Surface (not primary) for neutrality.
- Scroll behavior: add subtle divider (1px line) once user scrolls (SliverAppBar + `showOnScroll` flag).
- Fullscreen reading mode: Transparent + blur (BackdropFilter), icons shift to onSurface color.

**BottomNavigationBar**
- Elevated capsule container: radius 16, padding horizontal 12, height 64.
- Active item: Primary color + 100% label; inactive: Muted 60%.
- Optional medium bounce animation on selection (scale 0.92 → 1.0, 140ms).

**Cards (Unified)**
- shape: RoundedRectangleBorder(radius 12)
- padding internal: 16 content / 12 list
- border: hairline (#0000000F) instead of heavy shadow for dark-on-light lists
- interactive overlay: Primary at 6% (hover), 12% (pressed)

### 2.2 Surah List (Home)
**Item Layout**
```
Column(
  crossAxisAlignment: start,
  children: [
    Row(
      children:[ Expanded(Text(surahName, style:titleMedium)), metaBadgesOrPlayIcon]
    ),
    SizedBox(height:4),
    Text("No. <n> • <ayahCount> ajete", style: bodySmall.muted)
  ]
)
```
- Remove colored circle; replace with inline textual meta.
- Add subtle play icon ghost button (outlined) at end for quick recitation.

**Responsive**
- ≤480dp: ListView
- 481–840dp: Grid (2 columns) item min width ~ 320
- >840dp: 3 columns
- Use `SliverLayoutBuilder` or `LayoutBuilder` + delegate.

**Loading State**
- Shimmer placeholders: Rectangular blocks with radius 12, height 72.

### 2.3 Reading Screen (Surah Detail)
**Ayah Card Structure**
- VerseNumberChip top-right (or top-left in LTR layout) – capsule: bg primary 8% / text primary 80%.
- Arabic block → 6px gap → Translation → optional Transliteration (italic, muted, 4px gap).
- Inline actions: Densified row (icons 20) collapsed behind a 3-dot trigger OR always visible with muted style; fade to full opacity on focus/hover/selection.

**Interaction Modes**
- Playback highlight: Accent fill 14% + left border accent 3px + animated ColorTween 600ms.
- Selection Mode: Checkbox leading; when >0 selected, AppBar morphs to selection count; bottom bulk action bar slides in (Copy, Share, Favorite, Remove, Image).

**Spacing**
- Outer padding vertical 12 per ayah; internal block spacing 6 / 4.

### 2.4 Search Screen
**Result Item**
- Layout: Arabic line (if included) → Translation line → Meta row (Surah • Ayah • Juz).
- Highlight: Use background accent 28% + rounded radius 4 behind each token match (precomputed spans).
- Meta row style: bodySmall muted; vertical spacing 6.
- Grouping: Sticky headers per Surah (SurfaceVariant background, padding 8).
- Filters Summary Bar: Horizontal scrollable chips below search field summarizing active filters (e.g., “Juz 5”, “Arabic”, “Translation”). Tapping a chip toggles it.
- Empty State: Center illustration (icon: search), message + suggestions (chips with sample queries: `2:255`, `namazi`, `mëshira`).

**Performance**
- Use `ListView.builder` with `AutomaticKeepAliveClientMixin` only for interactive states (avoid over-keeping nodes).
- Precompute highlight spans off main isolate if match count > threshold (e.g., 400 verses).

### 2.5 Other Screens
**Texhvid**
- Rules as accordions: custom ExpansionTile (no heavy divider, subtle arrow rotation, 180ms). Arabic exemplars inside tinted surface (#Primary 6%).

**Indeksi Tematik**
- Tablet two-pane: Left narrow rail (280dp) listing categories; right detail scroll. Phone remains single column push navigation.

**Favorite / Memorizim / Bookmarks / Notes**
- Reuse AyahCard with context label (badge top-left: Favorit / Memorizim etc.).
- Sorting segmented control (Recent | A–Z | Sure) at top inside surface container radius 12.

**Settings**
- Group sections: Appearance / Reading / Audio / Notifications / Advanced.
- Use SectionHeader (label uppercase, letterSpacing +0.5, color muted).
- Toggle row pattern: Leading icon (24) → Title + subtitle column → Switch trailing.

---
## 3. Micro-Interactions & UX Enhancements

### 3.1 Motion Guidelines
- Durations: 150ms (small), 220ms (medium), 350ms (context / entrance). Curve: standard fastOutSlowIn.
- Stagger lists: index * 20ms (cap 200ms) on opacity+translateY (8px → 0).

### 3.2 Specific Animation Points
| Context | Animation |
|---------|-----------|
| Surah list appear | Staggered fade/slide |
| Search results change | AnimatedSwitcher crossfade 200ms |
| Ayah highlight (audio) | Color + subtle scale pulse 1.00→1.02→1.00 (450ms) |
| Enter selection mode | AppBar morph (size + color) + bottom bar slideUp |
| Filter chip toggle | Scale 0.92→1.0 + color tween |
| Fullscreen reader toggle | AppBar fade out/in + system overlays change |

### 3.3 Haptics (Platform Support Aware)
- Long-press ayah (enter selection): mediumImpact
- Play/Pause: lightImpact
- Bookmark / Favorite success: selectionClick
- Error (copy fail / share fail): vibration pattern fallback

### 3.4 Auto-Scroll (Audio Mode) – UX Spec
Trigger Conditions:
- New verse event received.
- User has not manually scrolled in last 3s (manualScrollCooldown timer).

Behavior:
- If verse widget >60% visible: only highlight.
- Else animate to center offset (clamped speed: duration = min(600ms, 22ms * pixelDistance/10)).
- New verse cancels previous animation (maintain controller ref).
- Setting: "Autoscroll during audio" (default ON). If Reduce Motion ON → instant jump (no animation) + highlight only.

Highlight:
- Background accent 14%, left border 3px, corner radius 8; fade out after 3s to normal surface (AnimatedOpacity).

### 3.5 Accessibility & Preferences
- Dynamic text size scaling integrated with tokens (no overflow at ≥1.3 system scale).
- Contrast validation (lint script can snapshot theme pairs for WCAG checks).
- Reduce Motion setting gates all non-essential scale / slide animations (retain fades).

---
## 4. Implementation Roadmap (Sprints)
Each sprint deliverable passes: Visual parity with spec, no performance regression (frame build p95 <16ms), all tests green.

| Sprint | Focus | Key Artifacts |
|--------|-------|---------------|
| 1 | Foundation | design_tokens.dart, theme.dart, typography scaler |
| 2 | Global Shell | Refactored AppBar, BottomNav, Card primitives, adaptive util |
| 3 | Surah List | Responsive grid, new item layout, shimmer loaders |
| 4 | Reading View | AyahCard refactor, actions minimization, autoscroll polish |
| 5 | Search | Result grouping, highlight spans, filters summary, empty state |
| 6 | Secondary Screens | Texhvid accordion, thematic two-pane, unified cards |
| 7 | Interaction Polish | Animations, haptics, selection bulk actions |
| 8 | Accessibility & Prefs | Reduce motion, persisted filter settings, contrast audit |

Parallel Quick Wins (insert opportunistically):
- Preference persistence for search filters & autoscroll toggle.
- Golden tests for core components post-refactor.

---
## 5. Metrics & Validation
Quantitative:
- Initial cold start layout shift count: baseline vs refactor (target: no increase).
- Average frame build time (profile mode) unchanged or improved.
- Search result comprehension test: reduce user time-to-first relevant verse.

Qualitative:
- User feedback (pilot group) on readability (Likert 1–5) target ≥4.5.
- Perceived distraction: actions not visually dominant (survey).

---
## 6. Engineering Integration Notes
- Refactor incrementally behind feature flags if needed (e.g., `useNewReaderUI`).
- Keep old Ayah widget until new passes QA → then delete.
- Provide storybook / component gallery (optional) for visual regression review.
- Create `VerseHighlightController` utility to encapsulate autoscroll + highlight logic (testable).

---
## 7. Risk & Mitigation
| Risk | Impact | Mitigation |
|------|--------|------------|
| Typography reflow regressions | Layout shifts | Lock height rhythms with fixed lineHeights |
| Extra rebuilds from animation | Jank | Use `AnimatedBuilder` + `RepaintBoundary` around verse list |
| Over-saturated highlight | Eye strain | Keep accent fill ≤18% opacity |
| Selection mode complexity | UX confusion | Clear entry animation + count AppBar + exit affordance |

---
## 8. Summary
This plan introduces a disciplined design system, elevates reading ergonomics, streamlines visual hierarchy, and adds purposeful motion & feedback— all while respecting performance constraints. Executed in staged sprints, it minimizes risk and steadily transforms the product into a premium, contemplative study experience.

---
## 9. Next Immediate Steps (Actionable)
1. Implement `design_tokens.dart` + theme wiring (central color tokens + spacing + radii).
2. Build enriched `ThemeData` (light + dark) that maps existing AmiriQuran & Lora into `TextTheme` (fonts ALREADY integrated — skip asset work).
3. Extract current inline Arabic / translation styles into semantic helpers (`context.textStyles.arabic`, `context.textStyles.translation`). Replace scattered inline `TextStyle` usages incrementally (start with `quran_view_widget.dart`).
4. Introduce highlight spec (accent 14% bg + 3px left border) in reading view; replace current secondaryContainer opacity usage.
5. Refactor Surah list item: remove colored circle; adopt new hierarchy + lighter meta line. (Keeps ListView for now; grid adaptivity can follow.)
6. Add persistence fields for search filter chips & (future) autoscroll toggle in `AppSettings` (search filters UI already present; just persist + hydrate).
7. Optional quick win: Wrap auto-scroll logic into a small controller class to decouple from widget state for future animation reduction / accessibility toggle.

Then proceed to Sprint 2 scope (AppBar, BottomNav, Card primitives) once typography + tokens merged to main.

Dependencies ordering rationale:
- Tokens before component refactors to avoid double churn.
- Surah list re-layout before AyahCard so navigation surfaces first benefit of new system quickly.
- Persistence early to avoid users losing newly introduced filter preferences across sessions.

Risk note: Keep highlight visual change behind a temporary flag (`kUseNewVerseHighlight`) until verified on both light & dark.

Performance guard: Profile frame build after steps 3 & 5; ensure no regression (>1ms p95) from additional style indirection.

Success checkpoint criteria update:
- ≥80% of Arabic & translation text usages migrated to centralized styles.
- New Surah list passes visual spec screenshots.
- No increase in start-up time (macrobenchmark) vs pre-refactor commit.

Updated because fonts & baseline auto-scroll already exist; focus shifts to formalization and visual hierarchy changes.

---

## 10. Implementation Status Audit (Updated 2025-08-17)
| Area | Plan Element | Status | Notes |
|------|--------------|--------|-------|
| Typography Assets | Amiri / Lora integration | Done | Declared & used (`pubspec.yaml`, multiple widgets). |
| Typography System | Central scale & tokens | Done | `design_tokens.dart` + `theme.dart` created. |
| Color System | Three curated palettes | Done | Sepia, Deep Blue, Minimal Dark schemes implemented. |
| Cards | Unified radius/elevation/border spec | Partial | CardTheme applied; still some legacy paddings elsewhere. |
| Surah List | Remove colored circle / new hierarchy | Done | Refactored layout + themed Arabic style. |
| Surah List | Responsive grid on tablet | Not yet | Only `ListView.builder`. |
| Reading View | Highlight style (accent bg + border) | Done | Accent 14% + 3px left border via helper + per-word sync engine. |
| Reading View | Auto-scroll w/ suppression | Done | Throttle + suppression + persisted toggle. |
| Reading View | Compact action buttons (subtle) | Not yet | Full-intensity icons always visible. |
| Reading View | Selection / multi-select mode | Not yet | No selection state in UI. |
| Search | Filter chips & Juz | Done | Implemented; not persisted. |
| Search | Grouped results + sticky headers | Not yet | Current layout (group status unverified but no grouping code observed). |
| Search | Highlight token background spans | Partial | Using tertiary container; span radius improvement pending. |
| Texhvid | Custom accordion rules | Not yet | Existing widget simple list (per plan). |
| Thematic Index | Two-pane tablet layout | Not yet | Single-column design currently. |
| Preferences | Persist search field filters & Juz | Done | searchInArabic/Translation/Transliteration/Juz added. |
| Preferences | Autoscroll toggle & reduce motion | Partial | Autoscroll persisted; reduceMotion flag stored (AppSettings) – gating not fully wired to animations yet. |
| Micro-interactions | Staggered list / AnimatedSwitcher | Not yet | No animation wrappers for lists. |
| Icons | Outlined uniform style | Not yet | Mixed filled icons. |
| Accessibility | Contrast audit / reduce motion gating | Not yet | No gating flag. |

Summary: Foundation (tokens, palettes, theme, verse styling, filter persistence) largely in place. Remaining high-impact items: adaptive typography scaler, responsive Surah grid, search result grouping + span radius styling, selection mode, reduce motion preference, and component polish (BottomNav/AppBar variants).

## 11. Progress Log (Sprint 1)
- Added design tokens & theme with three color schemes.
- Migrated Arabic / translation / transliteration text to semantic styles.
- Implemented new verse highlight + helper + word-by-word highlight style.
- Refactored Surah list & verse number chip styling.
- Persisted and integrated search filters (Arabic, Translation, Transliteration, Juz) and autoscroll setting.
- Centralized search highlight colors to theme accent.
- Refactored Help page into structured model using tokens.

Next Focus (Sprint Continuation): Typography scaler, search result chip grouping & highlight radius, responsive Surah grid, selection mode scaffolding.
