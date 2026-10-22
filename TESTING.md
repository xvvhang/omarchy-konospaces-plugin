# Validation record

Checked 2026-10-19 on Omarchy 4.0.5-1, Qt 6.12.0.

- Manifest validation and Qt 6 qmllint: passed for all QML files.
- Running shell: enabled; edited plugin hot-reloaded without a QML load error.
- Uses its permanent `konochi.konospaces` module name; clone metadata removed.
- Process lookup tests: `python3 -B -m unittest test_process_apps -v`.

## 1.1.0 — 2026-10-22

Five process lookup tests passed (symlink/PATH resolution,
literal wrapper targets, ambiguous matches, inaccessible processes, invalid PIDs).
A live Quickshell probe using the installed desktop-entry list resolved an
unidentified window process to its desktop entry, including launcher identity
fallback. Manifest validation passed; qmllint reports only Style qualification
warnings.

Full manual workspace/special-workspace switching, icon fallback, vertical bar,
multi-monitor behavior, restart, and destructive uninstall testing remain to
be performed before requesting marketplace approval.
