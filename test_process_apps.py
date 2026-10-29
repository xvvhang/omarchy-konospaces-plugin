import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("process_apps", Path(__file__).with_name("process-apps.py"))
resolver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolver)


class ProcessAppTests(unittest.TestCase):
    def test_scripts_are_not_interpreted(self):
        with tempfile.TemporaryDirectory() as directory:
            wrapper = Path(directory) / "launcher"
            wrapper.write_text('#!/bin/sh\nexec /opt/another-program "$@"\n')
            self.assertEqual(resolver.executable_path(str(wrapper)), str(wrapper))

    def test_relative_path_requires_absolute_working_directory(self):
        self.assertIsNone(resolver.executable_path("./example"))
        self.assertEqual(resolver.executable_path("./example", "/opt/app"), "/opt/app/example")

    @patch.object(resolver.os, "readlink", return_value="/opt/example/app")
    @patch.object(resolver.os.path, "realpath", return_value="/opt/example/app")
    @patch.object(resolver.shutil, "which", return_value="/usr/bin/example")
    def test_resolves_path_command_and_symlink(self, which, realpath, readlink):
        entries = [{"id": "example", "executable": "example"}]
        self.assertEqual(resolver.resolve_process_apps(entries, [123]), {"123": "example"})
        which.assert_called_once_with("example")

    @patch.object(resolver.os, "readlink", return_value="/usr/bin/foot")
    def test_shared_terminal_executable_is_not_guessed(self, readlink):
        entries = [{"id": name, "executable": "/usr/bin/foot"} for name in ["foot", "foot-server"]]
        self.assertEqual(resolver.resolve_process_apps(entries, [123]), {})

    @patch.object(resolver.os, "readlink", side_effect=PermissionError)
    def test_inaccessible_process_is_ignored(self, readlink):
        self.assertEqual(resolver.resolve_process_apps([], [123]), {})

    @patch.object(resolver.os, "readlink")
    def test_invalid_pids_are_ignored(self, readlink):
        self.assertEqual(resolver.resolve_process_apps([], [-1, 0, True, "123"]), {})
        readlink.assert_not_called()


if __name__ == "__main__":
    unittest.main()
