# Konospaces

Part of **Konochi**, a personal Omarchy plugin series by Alec Xu.

Standalone plugin derived from `omarchy.workspaces`, configured in
`~/.config/omarchy/shell.json`.

- Each workspace number is followed by one application icon per window (no deduplication).
- Workspaces containing windows and the selected workspace are shown, including special workspaces. Empty unselected workspaces are hidden.
- Normal workspaces appear first, followed by special workspaces using their names.
- The focused workspace number uses the theme accent.
- Click anywhere in a workspace group to switch to it. Hover to see window titles.
- Window creation, closure, and workspace moves update through Quickshell's Hyprland models.
- Application icons are resolved from desktop entries, with a generic fallback.
- The focused window icon uses its original colors and full opacity. Other window icons use the monochrome filter at 50% opacity.
- Supports horizontal and vertical bars. Clicking a special workspace toggles it.

Edit `Workspaces.qml` to customize icon size and spacing. If hot reload retains old code,
run `omarchy restart shell`.

Restore the stock widget with `omarchy plugin enable omarchy.workspaces`.

## Install and remove

Requires Omarchy Quattro, Quickshell's Hyprland integration, `hyprctl`, and
Hyprland with the `hl.dsp` Lua dispatch interface. Application icons come from
installed desktop entries. No network access, privileged setup, or installer.

```sh
omarchy plugin add https://github.com/xvvhang/konospaces --enable
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
```

Use Qt 6's qmllint (the default executable may be Qt 5).
MIT licensed; includes Omarchy-derived code, attributed in LICENSE.
