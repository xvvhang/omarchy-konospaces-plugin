"""Read-only fallback: match a PID to a unique desktop-entry executable.

Only paths and symlinks are resolved. Scripts, argv, and terminal titles are
deliberately not interpreted; multiple entries for one executable stay ambiguous.
"""

import json
import os
import shutil
import sys


def executable_path(command, working_directory=""):
    if not command:
        return None
    if os.path.isabs(command):
        path = command
    elif "/" in command:
        if not os.path.isabs(working_directory):
            return None
        path = os.path.join(working_directory, command)
    else:
        path = shutil.which(command)
    return os.path.realpath(path) if path else None


def resolve_process_apps(entries, pids):
    executables = {}
    for entry in entries:
        path = executable_path(entry["executable"], entry.get("workingDirectory", ""))
        if path:
            executables.setdefault(path, set()).add(entry["id"])

    matches = {}
    for pid in pids:
        if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
            continue
        try:
            path = os.path.realpath(os.readlink(f"/proc/{pid}/exe"))
        except OSError:
            continue
        ids = executables.get(path, set())
        if len(ids) == 1:
            matches[str(pid)] = next(iter(ids))
    return matches


if __name__ == "__main__":
    request = json.loads(sys.argv[1])
    print(json.dumps(resolve_process_apps(request["entries"], request["pids"])))
