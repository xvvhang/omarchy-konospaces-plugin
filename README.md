# Konospaces

Workspace numbers with per-window application icons or names for Omarchy.
Part of **Konochi** by Alec Xu, derived from `omarchy.workspaces`.

![Konospaces workspace widget](preview.png)

## Install

Requires Omarchy 4.5 or later, Quickshell's Hyprland integration, Hyprland's Lua
dispatch interface, `hyprctl`, Python 3, and `xdg-terminal-exec`.

```sh
omarchy plugin add https://github.com/xvvhang/omarchy-konospaces-plugin --enable
omarchy plugin disable omarchy.workspaces
```

## Usage

### New in 1.3.0: Omarchy 4.5 support

- Each bar shows its own display's occupied/current regular workspaces, with local
  1–10 labels. Ordinary named workspaces remain ordinary even with negative IDs.
- A layout icon on the left shows tiling, scrolling, or floating. Click to cycle
  the layout; it is disabled while an overlay is open. Layout-file changes are
  watched with inotify, not polling, including keyboard-driven changes.
  Floating is a regular-workspace layout, not a separate special workspace.
- Scratchpad, Quake console, and custom special workspaces use single Nerd Font
  icons rendered with Omarchy's native OpticalGlyph sizing, without a separator.
  The markers are Clipboard Outline (scratchpad), Terminal (console), and Dock Window
  (minimized windows). Opening an overlay highlights only that overlay, not the
  underlying numbered workspace; closing it restores the numbered highlight.
  Workspace emphasis follows what this display is showing, not which workspace
  owns the active window. Selecting a regular workspace closes the local overlay.
  Other displays are not toggled.
- `special:minimized` is never offered as a switchable workspace. After the Dock
  Window marker, each minimized window appears directly as an application icon or
  name, following the
  selected display mode. Click an entry to restore that exact window into the
  regular workspace shown on this display when clicked, focus it, and raise it.
  Hover for its full title, source workspace, and restore destination. No popup.
  Marker-to-window spacing matches Scratchpad; each window remains independently
  clickable.
- Active workspaces and windows use emphasis/color only; no underline is added.
- Inactive regular and special workspace markers share the bar foreground and
  50% opacity. Hidden workspace windows cannot retain focus styling; the minimized
  group marker uses the same dimmed style. Original application icons keep their colors.
- System `special:screensaver` is hidden. Reading state never opens a console or
  starts its default agent. Existing windows and application identities are reused.
- Minimized windows are listed globally on each bar; restore targets the display
  whose bar was clicked. Source tags are informational, not current ownership.
- Actions recheck live window/display state, reject storage-workspace navigation,
  and do not edit Hyprland configuration. No new global keybindings are installed.

Multi-display classification is covered by policy tests; physical multi-monitor
and vertical-bar validation of the new 4.5 behavior is still pending. See
[TESTING.md](TESTING.md) for verified behavior and remaining manual checks.

### Existing behavior

- Left-click a workspace to switch; interactive special workspaces toggle.
- Right-click to cycle through monochrome icons (default), application names,
  and original full-color application icons.
- Monochrome icons use the bar text color, with detail represented by opacity:
  55–100% for active windows and 20–65% for inactive windows. Original icons
  keep their colors, with 100% opacity when active and 50% when inactive.
- Occupied and selected workspaces are shown; inactive windows are dimmed.
- Hover to see window titles. Horizontal and vertical bars are supported.
- Omarchy launcher identities resolve to installed applications:
  `org.omarchy.nvim` → **Neovim**; `org.omarchy.terminal` → the default terminal.

Optional settings on the widget entry in `~/.config/omarchy/shell.json`:

```json
{"id": "konochi.konospaces", "displayMode": "text", "windowNameMaxWidth": 100}
```

`displayMode` accepts `icons` (monochrome), `text`, or `original` (full color).

Names and icons share desktop-entry matching, with explicit Omarchy/web-app
adapters. After exact/explicit matching, a unique case-insensitive desktop ID or
StartupWMClass match is tried before the PID/executable fallback. Ambiguous
case-insensitive matches are ignored. Process matching prefers the full resolved
executable path, then a unique executable basename to support wrapper launchers.
Titles and launcher scripts are
not used to guess application identity. No application commands are executed.

## Known issues

- Windows without usable application IDs whose executable path or basename does
  not uniquely match a desktop entry may display `Window` with a generic icon.
- Ambiguous executable matches are deliberately ignored. Unmatched windows show
  their raw app ID/class, or `Window` if neither is available.
- Web-app matching depends on URL-derived browser IDs and may not cover every browser.
- Plugin rescanning may retain old QML; use `omarchy restart shell` if needed.
- Default-terminal discovery runs at startup; restart the shell after changing it.

Inspect live identities, match sources, errors, and label text:

```sh
omarchy-shell konochi.konospaces status
```

The status includes display, base workspace, active overlay, layout, minimized
window origins, and inline labels. `omarchy-shell konochi.konospaces refresh`
refreshes all bar instances.

## Remove

```sh
omarchy plugin disable konochi.konospaces
omarchy plugin enable omarchy.workspaces
omarchy plugin remove konochi.konospaces
```

Back up unpushed changes before removal.
See [CHANGELOG.md](CHANGELOG.md) and [TESTING.md](TESTING.md) for development notes.
MIT licensed; Omarchy attribution is in [LICENSE](LICENSE).
