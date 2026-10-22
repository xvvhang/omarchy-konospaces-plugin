import importlib.util
from pathlib import Path
import unittest
import tempfile
from unittest.mock import patch


spec = importlib.util.spec_from_file_location("process_apps", Path(__file__).with_name("process-apps.py"))
resolver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(resolver)


class ProcessAppTests(unittest.TestCase):
    def test_literal_wrapper_exec_is_resolved_without_execution(self):
        with tempfile.TemporaryDirectory() as directory:
            executable = Path(directory) / "application"
            executable.write_bytes(b"\x7fELF")
            wrapper = Path(directory) / "launcher"
            wrapper.write_text(f'#!/bin/sh\nexec "{executable}" "$@"\n')
            self.assertEqual(resolver.executable_path(str(wrapper)), str(executable))
            wrapper.write_text('#!/bin/sh\nexec "$DYNAMIC_TARGET" "$@"\n')
            self.assertEqual(resolver.executable_path(str(wrapper)), str(wrapper))

    @patch.object(resolver.os, "readlink", return_value="/opt/example/app")
    @patch.object(resolver.os.path, "realpath", return_value="/opt/example/app")
    @patch.object(resolver.shutil, "which", return_value="/usr/bin/example")
    def test_resolves_path_command_and_symlink(self, which, realpath, readlink):
        entries = [{"id": "example", "executable": "example"}]
        self.assertEqual(resolver.resolve_process_apps(entries, [123]), {"123": "example"})
        which.assert_called_once_with("example")

    @patch.object(resolver.os, "readlink", return_value="/usr/bin/shared")
    def test_ambiguous_executable_is_not_guessed(self, readlink):
        entries = [{"id": name, "executable": "/usr/bin/shared"} for name in ["one", "two"]]
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
