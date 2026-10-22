"""Resolve window processes to unambiguous desktop entries without launching them."""

import json
import os
import shlex
import shutil
import sys
from pathlib import Path


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
    if not path:
        return None
    path = os.path.realpath(path)
    visited = set()
    for _ in range(8):
        if path in visited:
            break
        visited.add(path)
        try:
            with Path(path).open("rb") as script:
                data = script.read(65537)
            if len(data) > 65536 or not data.startswith(b"#!"):
                break
            targets = []
            for line in data.decode("utf-8").splitlines():
                if not line.lstrip().startswith("exec "):
                    continue
                args = shlex.split(line, comments=True)
                if len(args) > 1:
                    targets.append(args[1])
            if len(targets) != 1 or any(char in targets[0] for char in "$`*?[]{}~"):
                break
            target = targets[0]
            target = target if os.path.isabs(target) else shutil.which(target) if "/" not in target else None
            if not target:
                break
            path = os.path.realpath(target)
        except (OSError, UnicodeError, ValueError):
            break
    return path


def resolve_process_apps(entries, pids):
    executables = {}
    for entry in entries:
        path = executable_path(entry["executable"], entry.get("workingDirectory", ""))
        if path:
            executables.setdefault(path, set()).add(entry["id"])

    matches = {}
    for pid in set(pids):
        if not isinstance(pid, int) or isinstance(pid, bool) or pid <= 0:
            continue
        try:
            path = os.readlink(f"/proc/{pid}/exe")
        except OSError:
            continue  # Exited or inaccessible process.
        ids = executables.get(path, set())
        if not ids:
            # Launchers can preserve their identity in argv[0] while exec'ing a
            # different binary. Only accept absolute paths, never search PATH
            # for an untrusted process-supplied name.
            try:
                with Path(f"/proc/{pid}/cmdline").open("rb") as command_line:
                    argv0 = os.fsdecode(command_line.read(65536).split(b"\0", 1)[0])
                if os.path.isabs(argv0):
                    ids = executables.get(executable_path(argv0), set())
            except OSError:
                pass
        if len(ids) == 1:
            matches[str(pid)] = next(iter(ids))
    return matches


if __name__ == "__main__":
    request = json.loads(sys.argv[1])
    print(json.dumps(resolve_process_apps(request["entries"], request["pids"])))
