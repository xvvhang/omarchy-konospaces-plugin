# Validation record

Checked 2026-10-29 for the identity-resolver refactor (supersedes the earlier
terminal-argument matching attempt):

- 25 JavaScript identity-policy assertions and six Python process tests passed.
  Coverage includes exact desktop IDs/StartupWMClass, Omarchy command identity,
  default-terminal identity, web apps, missing metadata, ambiguity, current versus
  initial identity, title independence, and refusing script interpretation.
- Manifest validation and `git diff --check` passed. Qt 6 qmllint reports Style
  qualification warnings and dynamic Repeater-item property warnings in diagnostics;
  the resolver has no lint warnings.
- Restarted the shell after rescan did not expose the new status endpoint.
- Queried `omarchy-shell konochi.konospaces status` on the actual running bar,
  not an independent component. `org.omarchy.terminal` resolves to `Foot` using
  `xdg-terminal-exec --print-id`, with no process lookup errors.
- Reproduced Config > Hyprland using the real config-editor launcher. The status
  endpoint confirmed both the application identity and the actual label's `text`
  property as `Neovim`, source `omarchy-launcher`. No config file was edited.
- Explicit limitation: the current ID-less Feishu window behind a wrapper script
  now falls back to `Window`. This is intentional refusal to guess, not a successful
  application match. The old script/argv/title heuristics have been removed.

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
