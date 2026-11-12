# Changelog

## 1.4.1 — 2026-11-12

- Increase workspace marker/application spacing from 5 to 7 units, including
  the minimized-window strip, without changing spacing between applications.
- Keep a layout glyph visible while querying an uncached workspace's layout;
  cached destinations switch immediately without an intermediate blank frame.

## 1.4.0 — 2026-11-12

- Add a workspace-only display mode with native-style fixed-width numbers; cycle
  monochrome icons, application names, full-color icons, and no icons with right-click.
- Use the bar foreground instead of accent colors. Keep inactive workspace markers
  at 50% opacity and inactive full-color application icons at 30% opacity.
- Show the active window's original full-color icon in monochrome mode, while
  retaining monochrome opacity shading for other windows.
- Display the monitor-local tenth workspace as `0`, matching Omarchy.
- Cache layout results per workspace to prevent the previous workspace's layout
  flashing on a switch; retain the current icon during layout refreshes.
- Keep the layout control first, preserve natural number widths in application
  modes, and expose marker/content geometry in diagnostics.
- Add regression coverage for display modes, opacity, labels, and layout rendering.

## 1.3.0 — 2026-11-05

- Separate regular workspaces, interactive overlays, and minimized-window storage.
- Keep base-workspace context visible under Scratchpad/Quake console overlays;
  hide internal screensaver storage and never expose minimized storage directly.
- Show per-monitor workspace groups and local 1–10 labels; preserve named workspaces.
- Add layout display/cycling, event-driven layout invalidation, and inline
  minimized-window icons/names with monitor-scoped, address-targeted restore.
  Capture the clicked workspace so delayed commands cannot change the destination.
- Keep active-state emphasis/color without adding workspace/window underlines.
- Use the same bar foreground and 50% marker opacity for inactive regular/special
  workspaces and minimized storage. Gate window focus styling on viewed state,
  preventing stale focus metadata from brightening hidden overlay windows.
- Derive workspace emphasis only from this display's viewed workspace/open
  overlay, independent of active-window ownership. An open overlay takes exclusive
  highlight precedence over the base numbered workspace. Remove the group separator.
- Replace S / >_ / arrow markers with native-style, optically sized Nerd Font
  Clipboard Outline / Terminal / Dock Window icons and align the layout
  button slot with the stock widget's 20-unit width.
- Match minimized marker/window spacing to Scratchpad without duplicated button
  padding, while retaining independent restore targets.
- Preserve application matching and all three display modes. Escape dynamic
  tooltip text and render new UI text as plain text; add English/Chinese catalogs.
- Add policy/action tests for classification, multi-monitor isolation, origin
  metadata, markup-shaped input, stale actions, and layout file notifications.

## 1.2.2 — 2026-11-02

- Add unique case-insensitive desktop ID/StartupWMClass matching after exact and
  explicit matches, fixing applications such as Postman with differently cased IDs.
- Fall back from resolved executable paths to unique executable basenames for
  wrapper-launched applications without window IDs, including Feishu.
- Preserve exact-match priority and reject ambiguous fallback candidates; add
  regression tests for both matching policies.

## 1.2.1 — 2026-10-30

- Increase application icon spacing from 3 to 5 in both monochrome and original
  icon modes, including vertical layouts; keep text-mode spacing unchanged.
- Render application names in bold in text mode.

## 1.2.0 — 2026-10-30

- Add theme-colored monochrome application icons, preserving original icon detail
  through alpha coverage rather than darker RGB colors. Map opacity to 55–100%
  for active windows and 20–65% for inactive windows, preserving transparent edges.
- Cycle through monochrome icons, application names, and original full-color
  icons with right-click; persist the selected mode and include it in diagnostics.
- Include the shader source, compiled Qt 6 shader, and regeneration instructions.

- Separate application identity policy, reactive data collection, and bar rendering.
- Resolve `org.omarchy.<command>` through the Omarchy TUI-launcher contract;
  for example, config-editor windows now identify as Neovim rather than Foot.
- Prefer exact desktop IDs/StartupWMClass and unique executable matches. Remove
  script parsing, argv inference, title matching, and parameter-prefix guesses.
- Refresh process fallback from model changes instead of a fixed openwindow delay;
  discard stale query results and report subprocess errors.
- Add live widget diagnostics with match sources and displayed labels, plus
  pure JavaScript identity-policy tests.

## 1.1.0 — 2026-10-22

- Right-click workspace numbers or window icons/labels to toggle icon and text modes; persist the choice in shell configuration.
- Show installed application names for all windows in text mode, including the active window; retain full window titles in tooltips.
- Add configurable application-name width with overflow elision and active/inactive opacity differences.
- Resolve installed web app names from desktop-entry launch URLs.
- Share application matching between names and icons, removing application-specific exceptions.
- Add asynchronous, read-only PID/executable matching, including symlinks, literal launcher targets, and absolute launcher identities; skip ambiguous matches.
- Add process lookup unit tests. Python 3 is now required.

## 1.0.0 — 2026-10-19

- Initial standalone workspace widget with per-window application icons, special workspace support, and horizontal/vertical layouts.
