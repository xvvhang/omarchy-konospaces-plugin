# Validation record

## 1.4.2 — 2026-11-12

- Kept the native Omarchy layout reader/toggle helpers and Hyprland Lua dispatcher
  interfaces. Workspace names now use Lua string literals with literal UTF-8,
  escaped quotes/backslashes, and fixed-width decimal control-byte escapes.
- Real Lua 5.5.1 parser round-trips passed for Chinese workspace/overlay names,
  emoji, quotes, backslashes, all ASCII control bytes, NUL followed by digits,
  literal JSON-style escapes, and code-shaped strings. No compositor dispatch
  or focus change was used for this parser test.
- All five finite QML jobs use a shared supervisor: a 4-second whole-job deadline
  for monitor/layout/terminal/process queries and 15 seconds for actions. Stdout
  is capped at 1 MiB and stderr at 16 KiB while produced, before QML collection.
  Nonzero jobs discard partial stdout. A QML watchdog sends cancellation after
  an additional 2 seconds; cancellation kills the native job process group.
- Action helper child calls remain in the outer job's session, with bounded
  output and shorter individual deadlines. Final cleanup kills remaining native
  helper descendants even when their immediate parent exits successfully.
- Real native layout-reader testing with an isolated state directory, a FIFO
  mode path and a fixture compositor transport timed out and then recovered after
  replacing the FIFO with a regular mode file. User state files were not changed.
- Deadline, stdout/stderr flood, cancellation, descendant-cleanup and subsequent
  successful-job tests passed. Persistent `watch-modes` remains outside finite-job
  supervision. Original monitor/address revalidation and tooltip escaping remain.
- 34 Python tests and both JavaScript test suites passed; `git diff --check` passed.
  Restarted the actual Shell and confirmed terminal/process resolution and layout
  reading completed successfully through the new QML component.
- Physical multi-monitor/vertical-bar acceptance and marketplace approval remain
  outside this local validation record.

## 1.3.0 — 2026-11-05

- Subsequent visual feedback: workspace foreground depends on monitor-local viewed
  state, never active-window ownership. An open overlay exclusively takes the
  highlight; closing it restores the base numbered highlight. No separator or
  underline rectangles remain. Clipboard Outline / Terminal / Dock Window markers use
  Nerd Font glyphs with Omarchy's OpticalGlyph renderer. Policy tests cover exactly
  one highlighted destination for ordinary/console/scratchpad states and icon maps.
- Manifest validation and `git diff --check` passed on Omarchy 4.5.0-3.
- Existing JavaScript application identity tests and new pure workspace-policy
  tests passed: ordinary negative IDs, display-local labels, overlay classification,
  hidden storage, source tags, and markup-shaped tooltip input.
- All 20 Python process/action/UI-structure tests passed, including stale restore
  rejection, exact window addressing, clicked-workspace capture, no-underline/
  no-popup structure, overlay layout guard, and inotify mode-file creation.
- Restarted the actual Omarchy Shell to bypass stale QML component caching. Live
  diagnostics report the local display, base workspace, overlays, layout, and panel.
- Using one disposable Alacritty window on a dedicated test special workspace,
  verified overlay opening, persistent base context, selecting the regular
  workspace to dismiss the overlay, minimized-storage exclusion, recovery-panel
  creation, and restoring that exact window into the current regular workspace.
  Closed the test window and restored the prior focus afterward. No existing user
  window was moved, and no Quake console/default agent was started by the test.
- No new plugin QML errors in the restarted Shell log; Hyprland configerrors clean.
- Following UI feedback, removed the underline and recovery popup. Each minimized
  window now has its own inline WorkspaceChip in the selected icon/name mode.
  A subsequent disposable-window live test confirmed a real inline Alacritty
  identity/label, exclusion from workspace groups, and unchanged overlay state.
  Closed the test window afterward. The earlier popup test describes the initial
  preview, not the revised UI.
- Grouped the minimized marker and individual window targets into MinimizedStrip:
  matches WorkspaceChip's 5-unit marker gap and 8-unit inter-window gap without
  duplicated button padding. Spacing structure regression passed; after restarting
  Shell, the disposable inline-window smoke test passed with no matching QML errors.
  Pointer-click and vertical-bar acceptance checks below remain outstanding.
- Standalone qmllint/qmlformat reported a parse error at the existing
  `pragma ComponentBehavior: Bound` header; actual Quickshell loading and live
  interaction succeeded. Static QML lint is therefore not recorded as passed.
- Physical multi-monitor/hot-unplug, vertical-bar rendering, real Quake-console
  seeding, and end-to-end virtual-pointer clicking of inline Restore remain manual
  acceptance checks. Multi-monitor policy is unit-tested, not hardware-verified.
- Prepared version 1.3.0 from the locally tested preview; no marketplace submission
  or separate GitHub release is included in this validation record.

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
