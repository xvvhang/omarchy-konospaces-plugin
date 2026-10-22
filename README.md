# Konospaces

Part of **Konochi**, a personal Omarchy plugin series by Alec Xu.

Standalone plugin derived from `omarchy.workspaces`, configured in
`~/.config/omarchy/shell.json`.

Current version: **1.1.0**. See [CHANGELOG.md](CHANGELOG.md) for release notes.

## Preview

![Konospaces bar widget showing numbered workspaces and application icons for their windows](preview.png)

## Features

- Each workspace number is followed by one application icon or name per window (no deduplication). Icon mode is the default.
- Workspaces containing windows and the selected workspace are shown, including special workspaces. Empty unselected workspaces are hidden.
- Normal workspaces appear first, followed by special workspaces using their names.
- The focused workspace number is bold and fully opaque; other workspace numbers are dimmed.
- Left-click anywhere in a workspace group to switch to it. Hover to see window titles.
- Window creation, closure, and workspace moves update through Quickshell's Hyprland models.
- Application icons are resolved from desktop entries, with a generic fallback.
- The focused window icon uses its original colors and full opacity. Other window icons use the monochrome filter at 50% opacity.
- Right-click a workspace number or any window icon/label to toggle icon and text modes. The choice is saved in `shell.json` and shared across monitors.
- Text mode hides application icons. All windows, including the active window, show their installed application names, elided at 100 scaled pixels. If no desktop entry matches, the window class is used as a fallback. The active window uses full opacity; other windows are dimmed. Hover the workspace to read full titles.
- Installed web apps use their desktop-entry names instead of the browser class in text mode.
- Supports horizontal and vertical bars. Clicking a special workspace toggles it.

## Configuration

Settings belong on the `konochi.konospaces` entry in `bar.layout` in
`~/.config/omarchy/shell.json`:

```json
{
  "id": "konochi.konospaces",
  "displayMode": "text",
  "windowNameMaxWidth": 100
}
```

| Setting | Default | Description |
| --- | --- | --- |
| `displayMode` | `"icons"` | `"icons"` or `"text"`; right-click toggles and saves this setting. |
| `windowNameMaxWidth` | `100` | Maximum application-name width in scaled pixels (minimum 40); overflow is elided. |

Active and inactive windows use the same application-name display and width
limit. Window titles appear only in the workspace tooltip. Vertical bars
constrain labels to the bar width. The former `activeTitleMaxWidth` setting
is no longer used.

## Application matching

Names and icons share the same desktop-entry lookup, with no application-specific
exceptions. URL-derived window IDs are matched to desktop-entry launch URLs for
installed web apps; other identifiers use Quickshell's desktop-entry lookup.

When identifiers cannot resolve an application, a read-only PID/executable lookup
matches desktop entries by resolved executable path, following symlinks and
literal `exec` targets in small launcher scripts. Absolute `argv[0]` paths are
also checked for applications that preserve a launcher identity. Ambiguous
process matches are ignored. No launcher or application command is executed.
An exact desktop-name/title match is a final fallback for windows without IDs.

Unresolved names fall back to the window class/app ID, then `Window`; unresolved
icons use the generic application icon. Process lookup runs asynchronously on
startup, window creation/closure, and desktop-entry list changes.

Edit `Workspaces.qml` to customize icon size and spacing. If hot reload retains old code,
run `omarchy restart shell`.

Restore the stock widget with `omarchy plugin enable omarchy.workspaces`.

## Install and remove

Requires Omarchy Quattro, Quickshell's Hyprland integration, `hyprctl`, Python 3, and
Hyprland with the `hl.dsp` Lua dispatch interface. Application icons come from
installed desktop entries. No network access, privileged setup, or installer.

```sh
omarchy plugin add https://github.com/xvvhang/omarchy-konospaces-plugin --enable
omarchy plugin disable omarchy.workspaces
```

The published manifest has no development-only clone metadata. Restore the stock
widget explicitly when uninstalling:

```sh
omarchy plugin disable konochi.konospaces
omarchy plugin enable omarchy.workspaces
omarchy plugin remove konochi.konospaces
```

No persistent data is stored outside the shell configuration. Back up unpushed
development changes before removal.

## Validation

```sh
omarchy plugin validate .
/usr/lib/qt6/bin/qmllint -I /usr/share/omarchy/shell ./*.qml
python3 -B -m unittest test_process_apps -v
```

Use Qt 6's qmllint (the default executable may be Qt 5).
See [TESTING.md](TESTING.md) for validation results and remaining manual checks.
MIT licensed; includes Omarchy-derived code, attributed in LICENSE.
