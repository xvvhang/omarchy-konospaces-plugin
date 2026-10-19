# Validation record

Checked 2026-10-19 on Omarchy 4.0.5-1, Qt 6.12.0.

- Manifest validation and Qt 6 qmllint: passed for all QML files.
- Running shell: enabled; edited plugin hot-reloaded without a QML load error.
- Uses its permanent `xvvhang.workspaces` module name; clone metadata removed.
- No standalone automated unit-test suite is present.

Full manual workspace/special-workspace switching, icon fallback, vertical bar,
multi-monitor behavior, restart, and destructive uninstall testing remain to
be performed before requesting marketplace approval.
