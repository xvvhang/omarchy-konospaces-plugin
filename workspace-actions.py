"""Fresh-state, monitor-scoped actions and event-driven layout invalidation."""
import argparse
import ctypes
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys


def ctl(*arguments):
    result = subprocess.run(["hyprctl", *arguments], text=True, capture_output=True, check=True, timeout=5)
    output = result.stdout.strip()
    if output.startswith(("error", "Err", "Couldn't", "Invalid")):
        raise RuntimeError(output)
    return output


def dispatch(expression):
    result = ctl("dispatch", expression)
    if result != "ok":
        raise RuntimeError(result)


def quote(value):
    return json.dumps(str(value), ensure_ascii=True)


def address(value):
    if not re.fullmatch(r"(?:0x)?[0-9a-fA-F]{1,16}", str(value)):
        raise ValueError("Invalid window address")
    return "0x" + str(value).removeprefix("0x")


def current_monitor(name):
    return next((m for m in json.loads(ctl("monitors", "-j")) if m["name"] == name), None)


def focus_monitor(name):
    if not current_monitor(name):
        raise ValueError("Display is no longer connected")
    dispatch("hl.dsp.focus({ monitor = " + quote(name) + " })")


def close_overlay(name):
    monitor = current_monitor(name)
    if not monitor:
        raise ValueError("Display is no longer connected")
    special = monitor.get("specialWorkspace", {}).get("name", "")
    if special.startswith("special:"):
        dispatch("hl.dsp.workspace.toggle_special(" + quote(special[8:]) + ")")


def plan_restore(clients, monitor, requested):
    if not monitor:
        raise ValueError("Display is no longer connected")
    target = address(requested)
    window = next((w for w in clients if w.get("address", "").lower() == target.lower()), None)
    if not window or window.get("workspace", {}).get("name") != "special:minimized":
        raise ValueError("Window is no longer minimized")
    workspace = monitor.get("activeWorkspace", {})
    name = str(workspace.get("name", ""))
    if not name or name.startswith("special:"):
        raise ValueError("No regular workspace to restore into")
    return target, name


def restore_monitor(monitor_name, clicked_workspace):
    monitor = current_monitor(monitor_name)
    if not monitor:
        raise ValueError("Display is no longer connected")
    if clicked_workspace:
        if clicked_workspace.startswith("special:"):
            raise ValueError("No regular workspace to restore into")
        workspace = next((w for w in json.loads(ctl("workspaces", "-j"))
                          if w.get("name") == clicked_workspace and w.get("monitor") == monitor_name), None)
        if not workspace:
            raise ValueError("The clicked workspace is no longer on this display")
        monitor = {**monitor, "activeWorkspace": workspace}
    return monitor


def perform(action, monitor_name, target, clicked_workspace=""):
    monitor = current_monitor(monitor_name)
    if not monitor:
        raise ValueError("Display is no longer connected")
    # Validate before changing focus; a stale click must not toggle an unrelated
    # overlay or expose the minimized storage workspace.
    if action == "workspace":
        workspaces = json.loads(ctl("workspaces", "-j"))
        workspace = next((w for w in workspaces if w.get("name") == target and w.get("monitor") == monitor_name), None)
        if not workspace or target.startswith("special:"):
            raise ValueError("Workspace is no longer on this display")
    elif action == "overlay":
        if not target.startswith("special:") or target in ("special:minimized", "special:screensaver"):
            raise ValueError("Not an interactive overlay")
        if not any(w.get("name") == target for w in json.loads(ctl("workspaces", "-j"))):
            raise ValueError("Overlay no longer exists")
    elif action == "restore":
        monitor = restore_monitor(monitor_name, clicked_workspace)
        target, workspace_name = plan_restore(json.loads(ctl("clients", "-j")), monitor, target)
    elif action == "layout":
        if monitor.get("specialWorkspace", {}).get("id", 0):
            raise ValueError("Close the overlay before changing layout")
        if monitor.get("activeWorkspace", {}).get("id", 0) <= 0:
            raise ValueError("Layout switching requires a numbered workspace")
    focus_monitor(monitor_name)
    if action == "workspace":
        close_overlay(monitor_name)
        dispatch("hl.dsp.focus({ workspace = " + quote(target) + " })")
    elif action == "overlay":
        dispatch("hl.dsp.workspace.toggle_special(" + quote(target[8:]) + ")")
    elif action == "restore":
        close_overlay(monitor_name)
        # Revalidate after focus/overlay changes. Never act on whatever window
        # happens to have focus when the asynchronous command arrives.
        monitor = restore_monitor(monitor_name, clicked_workspace)
        target, workspace_name = plan_restore(json.loads(ctl("clients", "-j")), monitor, target)
        selector = 'window = "address:' + target + '"'
        dispatch("hl.dsp.window.move({ workspace = " + quote(workspace_name) + ", follow = false, " + selector + " })")
        dispatch("hl.dsp.focus({ " + selector + " })")
        dispatch('hl.dsp.window.alter_zorder({ mode = "top", ' + selector + " })")
    elif action == "layout":
        subprocess.run(["omarchy-hyprland-workspace-layout-toggle"], check=True, timeout=10)


def watch_modes():
    # inotify, not polling. Watch the parent as well so creation/replacement of
    # workspace-layouts and previously nonexistent mode files is observed.
    parent = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "omarchy"
    directory = parent / "workspace-layouts"
    libc = ctypes.CDLL(None, use_errno=True)
    fd = libc.inotify_init1(os.O_CLOEXEC)
    if fd < 0:
        raise OSError(ctypes.get_errno(), "inotify_init1")
    watched = set()
    mask = 0x8 | 0x40 | 0x80 | 0x100 | 0x200 | 0x400 | 0x800  # close-write, move, create/delete, self changes
    def attach():
        for path in (parent.parent, parent, directory):
            if path.is_dir() and str(path) not in watched:
                if libc.inotify_add_watch(fd, os.fsencode(path), mask) >= 0:
                    watched.add(str(path))
    try:
        attach()
        print("refresh", flush=True)
        while True:
            data = os.read(fd, 65536)
            offset, changed = 0, False
            while offset + 16 <= len(data):
                wd, event, cookie, size = struct.unpack_from("iIII", data, offset)
                name = data[offset + 16:offset + 16 + size].split(b"\0", 1)[0].decode(errors="replace")
                offset += 16 + size
                if event & (0x400 | 0x800 | 0x8000):
                    watched.clear()
                    changed = True
                if name.endswith(".lua") or name in ("omarchy", "workspace-layouts"):
                    changed = True
            attach()
            if changed:
                print("refresh", flush=True)
    finally:
        os.close(fd)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["watch-modes", "workspace", "overlay", "restore", "layout"])
    parser.add_argument("monitor", nargs="?", default="")
    parser.add_argument("target", nargs="?", default="")
    parser.add_argument("clicked_workspace", nargs="?", default="")
    args = parser.parse_args()
    try:
        if args.action == "watch-modes":
            watch_modes()
        else:
            perform(args.action, args.monitor, args.target, args.clicked_workspace)
    except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
