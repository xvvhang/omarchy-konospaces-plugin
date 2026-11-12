import importlib.util
import json
import os
from pathlib import Path
import select
import shutil
import subprocess
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parent
spec = importlib.util.spec_from_file_location("workspace_actions", ROOT / "workspace-actions.py")
actions = importlib.util.module_from_spec(spec)
spec.loader.exec_module(actions)


class WorkspaceActionTests(unittest.TestCase):
    def test_workspace_names_round_trip_through_real_lua_parser(self):
        lua = shutil.which("lua5.5") or shutil.which("lua")
        if not lua:
            self.skipTest("Lua parser is not installed")
        values = ['研发', 'special:研发', 'emoji-🦉', '"\\',
                  ''.join(chr(n) for n in range(32)) + chr(127),
                  '\x00123\n456', '\\u7814', '\"); error("not code") --']
        for value in values:
            with self.subTest(value=value):
                result = subprocess.run([lua, '-'], input=('io.write(' + actions.quote(value) + ')').encode(),
                                        capture_output=True, check=True, timeout=2)
                self.assertEqual(result.stdout, value.encode())

    def test_restore_only_a_currently_minimized_exact_address(self):
        clients = [{"address": "0xabc", "workspace": {"name": "special:minimized"}}]
        monitor = {"activeWorkspace": {"name": "design", "id": -1300}}
        self.assertEqual(actions.plan_restore(clients, monitor, 'abc'), ('0xabc', 'design'))
        with self.assertRaises(ValueError): actions.plan_restore(clients, monitor, 'def')
        clients[0]['workspace']['name'] = '1'
        with self.assertRaises(ValueError): actions.plan_restore(clients, monitor, 'abc')

    def test_restore_rejects_missing_monitor_or_special_target(self):
        clients = [{"address": "0xabc", "workspace": {"name": "special:minimized"}}]
        with self.assertRaises(ValueError): actions.plan_restore(clients, None, 'abc')
        with self.assertRaises(ValueError): actions.plan_restore(clients, {"activeWorkspace": {"name": "special:qconsole"}}, 'abc')

    def test_address_validation(self):
        for invalid in ['; rm file', '$(cmd)', '0xg', '', 'a' * 17]:
            with self.subTest(invalid=invalid):
                with self.assertRaises(ValueError): actions.address(invalid)

    def test_no_focus_change_for_storage_workspace(self):
        with patch.object(actions, 'current_monitor', return_value={'name': 'A'}), patch.object(actions, 'dispatch') as dispatch:
            with self.assertRaises(ValueError): actions.perform('overlay', 'A', 'special:minimized')
            dispatch.assert_not_called()

    def test_layout_rejected_while_overlay_open(self):
        monitor = {'name': 'A', 'activeWorkspace': {'id': 1}, 'specialWorkspace': {'id': -99}}
        with patch.object(actions, 'current_monitor', return_value=monitor), patch.object(actions, 'dispatch') as dispatch:
            with self.assertRaises(ValueError): actions.perform('layout', 'A', '')
            dispatch.assert_not_called()

    def test_restore_keeps_the_clicked_workspace_after_focus_changes(self):
        monitor = {'name': 'A', 'activeWorkspace': {'id': 9, 'name': '9'}}
        workspaces = [{'id': 3, 'name': '3', 'monitor': 'A'}]
        with patch.object(actions, 'current_monitor', return_value=monitor), patch.object(actions, 'ctl', return_value=json.dumps(workspaces)):
            result = actions.restore_monitor('A', '3')
            self.assertEqual(result['activeWorkspace']['name'], '3')
            self.assertEqual(monitor['activeWorkspace']['name'], '9')

    def test_restore_rejects_a_deleted_or_moved_destination(self):
        with patch.object(actions, 'current_monitor', return_value={'name': 'A'}), patch.object(actions, 'ctl', return_value=json.dumps([{'name': '3', 'monitor': 'B'}])):
            with self.assertRaises(ValueError): actions.restore_monitor('A', '3')
            with self.assertRaises(ValueError): actions.restore_monitor('A', 'special:minimized')

    def test_inline_ui_has_no_panel_or_underline(self):
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        widget = (ROOT / 'Workspaces.qml').read_text()
        self.assertNotIn('Rectangle {', chip)
        self.assertNotIn('MinimizedPanel', widget)
        self.assertIn('hostWidget.restoreWindow(windows[0])', chip)
        self.assertIn('group.minimized ? ""', chip)
        self.assertIn('hasVisualContent: true', chip)
        self.assertNotIn('focusedWithin', chip)
        self.assertIn('foreground: bar ? bar.barForeground : Color.foreground', chip)
        self.assertNotIn('Color.accent', chip)
        self.assertIn('OpticalGlyph {', chip)
        self.assertNotIn('Rectangle {', widget)
        self.assertEqual(chip.count('opacity: chip.indicatorOpacity'), 2)
        self.assertIn('indicatorOpacity: shown ? 1 : 0.5', chip)
        self.assertIn('Policy.windowActive(chip.shown, modelData.activated)', chip)

    def test_layout_button_precedes_workspace_numbers(self):
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        widget = (ROOT / 'Workspaces.qml').read_text()
        self.assertNotIn('showsLayout', chip)
        self.assertIn('text: root.layoutGlyph', widget)
        self.assertIn('root.runAction("layout", "")', widget)
        self.assertIn('readonly property string layoutGlyph:', widget)
        self.assertLess(widget.index('id: layoutButton'), widget.index('id: workspaceRepeater'))

    def test_layout_is_bound_to_destination_workspace(self):
        widget = (ROOT / 'Workspaces.qml').read_text()
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        self.assertIn('activeMode: modeCache[activeWorkspaceId] || lastMode', widget)
        self.assertIn('property string lastMode: "dwindle"', widget)
        self.assertIn('root.lastMode = mode', widget)
        self.assertIn('next[modeProcess.workspace] = mode', widget)
        self.assertNotIn('modeCache = ({})', widget)
        self.assertIn('activeMode === "dwindle" ? "󱓻" : ""', widget)
        self.assertNotIn('hostWidget.layoutGlyph', chip)

    def test_no_icons_mode_hides_application_content(self):
        widget = (ROOT / 'Workspaces.qml').read_text()
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        self.assertIn('noIconsMode: displayMode === "none"', widget)
        self.assertIn('["icons", "text", "original", "none"]', widget)
        self.assertIn('visible: !chip.hostWidget.noIconsMode && chip.windows.length > 0', chip)
        self.assertIn('model: chip.hostWidget.noIconsMode ? [] : chip.windows', chip)
        self.assertIn('windows: root.noIconsMode ? [] : root.minimizedWindows', widget)

    def test_active_window_is_colored_in_monochrome_mode(self):
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        self.assertIn('visible: chip.hostWidget.originalIconMode || (!chip.hostWidget.textMode && windowItem.focused)', chip)
        self.assertIn('visible: !chip.hostWidget.textMode && !chip.hostWidget.originalIconMode && !windowItem.focused', chip)

    def test_icon_modes_use_distinct_opacity_rules(self):
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        self.assertIn('minimumOpacity: windowItem.focused ? 0.55 : 0.2', chip)
        self.assertIn('maximumOpacity: windowItem.focused ? 1.0 : 0.65', chip)
        self.assertIn('property color foreground: chip.foreground', chip)
        self.assertIn('opacity: !focused ? (chip.hostWidget.originalIconMode ? 0.3 : chip.hostWidget.textMode ? 0.5 : 1) : 1', chip)
        self.assertNotIn('brightForeground', chip)

    def test_workspace_numbers_use_natural_width(self):
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        for constraint in ('minimumWidth', 'preferredWidth', 'maximumWidth'):
            self.assertIn(f'Layout.{constraint}: implicitWidth', chip)
        self.assertIn('id: indicatorText\n        anchors.fill: parent', chip)
        self.assertIn('Math.min(indicatorText.implicitWidth, Style.space(chip.hostWidget.vertical ? 32 : 90))', chip)
        self.assertIn('horizontalAlignment: Text.AlignHCenter', chip)
        self.assertIn('width: Style.bar.iconCanvas', chip)

    def test_minimized_spacing_matches_overlay_spacing(self):
        chip = (ROOT / 'WorkspaceChip.qml').read_text()
        strip = (ROOT / 'MinimizedStrip.qml').read_text()
        for spacing in ('columnSpacing: Style.space(7)', 'columnSpacing: Style.space(8)'):
            self.assertIn(spacing, chip)
            self.assertIn(spacing, strip)
        self.assertIn('horizontalMargin: strip.hostWidget.vertical ? 6 : 0', strip)
        self.assertIn('fixedWidth: strip.hostWidget.vertical ? strip.hostWidget.barSize : naturalContentWidth', strip)

    def test_event_driven_mode_watcher(self):
        with tempfile.TemporaryDirectory(prefix='konospaces-watch-', dir='/tmp/opencode') as tmp:
            directory = Path(tmp) / 'omarchy/workspace-layouts'
            directory.mkdir(parents=True)
            process = subprocess.Popen(['/usr/bin/python3', str(ROOT / 'workspace-actions.py'), 'watch-modes'],
                                       env={**os.environ, 'XDG_STATE_HOME': tmp}, stdout=subprocess.PIPE)
            try:
                readable, _, _ = select.select([process.stdout], [], [], 2)
                self.assertTrue(readable)
                self.assertEqual(process.stdout.readline(), b'refresh\n')
                # A new file is observable even if it did not exist at startup.
                (directory / '3.lua').write_text('o.workspace_mode({workspace="3",mode="floating"})')
                readable, _, _ = select.select([process.stdout], [], [], 2)
                self.assertTrue(readable)
                self.assertEqual(process.stdout.readline(), b'refresh\n')
            finally:
                process.terminate()
                process.wait(timeout=3)
                process.stdout.close()


if __name__ == '__main__': unittest.main()
