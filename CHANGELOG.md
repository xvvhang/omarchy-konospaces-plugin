# Changelog

## Unreleased

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
