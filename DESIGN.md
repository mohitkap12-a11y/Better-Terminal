# Design Rules (read before building any UI)

Adapted from ibelick/ui-skills (web-focused) + Apple HIG, translated to SwiftUI/AppKit. macOS 14+.

## Look & feel
- Native first: `NavigationSplitView`, `Form`, `.toolbar`, `Settings` scene, SF Symbols, system fonts (SF Pro; SF Mono / user font in terminal only).
- One accent color per view. Accent comes from the theme, defaults to system accent.
- No decorative gradients or glows. Use materials (`.regularMaterial`) sparingly for sidebar/popovers.
- Spacing on a 4pt grid. Corner radius 8 (controls) / 12 (cards/popovers).
- Hierarchy via size/weight/opacity (`.primary`/`.secondary`/`.tertiary`), not extra colors.
- `.monospacedDigit()` for durations, counts, timestamps.
- Truncate with `.lineLimit(1)` + `.truncationMode(.middle)` for paths and commands.

## Theming
- `ThemeMode`: system / light / dark (`preferredColorScheme`).
- Themes = UI palette + ANSI terminal palette + accent. Never hardcode colors in views; read from `Theme` environment value.
- Contrast: text >= 4.5:1 in every theme (unit-tested).

## Motion
- Animate opacity/transform only. <= 200ms for interaction feedback, ease-out for entrances.
- No animation unless it clarifies state change. Honor `accessibilityReduceMotion`.

## Interaction & a11y
- Every icon-only button: `.accessibilityLabel` + `.help` tooltip.
- Full keyboard: Cmd-T new tab, Cmd-W close, Cmd-1..9 tabs, Ctrl-Cmd-1..9 workspaces, Cmd-K palette, Cmd-Shift-H history, Cmd-Opt-L layout picker.
- Destructive actions (close running tab, delete workspace) use confirmation dialogs.
- Empty states: one icon, one sentence, one primary action.
- Loading: skeleton/placeholder, never spinner-only for lists.
- Errors shown next to the action that caused them.
- Never block paste. Dynamic Type for non-terminal UI.

## Key components
- **Layout picker**: popover grid of mini diagrams (1x1, 1x2, 2x1, 1x3, 3x1, 2x2, 2x3, 3x2, 3x3) + custom rows/cols steppers. Hover previews, click applies, current is highlighted. Opens from toolbar button.
- **Sidebar** (MacPeek Remote style): 236pt full width or an 80pt icon rail (chevron on its edge), clears the traffic lights, workspace rows with colored badges, context menu (rename/color/delete), Search and Settings at the bottom.
- **Tab bar**: top, compact, close-on-hover, drag reorder, running indicator.
- **History drawer (per tab)**: popover/side drawer, newest first, search field, failed-command filter, relative timestamps, exit-code dot; click = insert at prompt, double-click or Cmd-click = run.
- **Settings**: a page inside the main window; sections (Appearance, Terminal, Updates, Data, Shortcuts, About) in one card, title/hint on the left, controls on the right.
