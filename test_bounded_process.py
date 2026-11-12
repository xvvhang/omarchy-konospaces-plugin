import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

from bounded_process import run

ROOT = Path(__file__).resolve().parent


class FiniteJobTests(unittest.TestCase):
    def test_success(self):
        result = run([sys.executable, "-c", "print('ok')"])
        self.assertEqual(result.stdout, "ok\n")

    def test_output_caps_apply_while_produced_to_both_streams(self):
        for stream in (1, 2):
            with self.subTest(stream=stream), self.assertRaisesRegex(RuntimeError, "output limit"):
                run([sys.executable, "-c",
                     f"import os\nwhile True: os.write({stream}, b'x' * 8192)"], timeout=1)

    def test_complete_chain_has_one_deadline(self):
        started = time.monotonic()
        with self.assertRaises(TimeoutError):
            run([sys.executable, "-c", "import time\nfor _ in range(20): time.sleep(.1)"], timeout=.25)
        self.assertLess(time.monotonic() - started, 1.5)
        self.assertEqual(run([sys.executable, "-c", "print('recovered')"]).stdout, "recovered\n")

    def test_descendants_are_stopped_on_deadline_and_success(self):
        for wait in (True, False):
            with self.subTest(wait=wait), tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
                pidfile = Path(directory) / "pid"
                code = ("import subprocess,sys,time\n"
                        "p=subprocess.Popen([sys.executable,'-c','import time; time.sleep(60)'], "
                        "stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)\n"
                        f"open({str(pidfile)!r},'w').write(str(p.pid))\n"
                        + ("time.sleep(60)\n" if wait else ""))
                if wait:
                    with self.assertRaises(TimeoutError):
                        run([sys.executable, "-c", code], timeout=.3)
                else:
                    run([sys.executable, "-c", code], timeout=2)
                pid = int(pidfile.read_text())
                # A killed orphan can briefly remain a zombie until init reaps it.
                for _ in range(100):
                    stat = Path(f"/proc/{pid}/stat")
                    if not stat.exists() or stat.read_text().split(") ")[1].startswith("Z"):
                        break
                    time.sleep(.01)
                else:
                    self.fail("Native helper descendant survived job cleanup")

    def test_cancellation_cleans_descendants(self):
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            pidfile = Path(directory) / "pid"
            child = ("import os,time\n"
                     f"open({str(pidfile)!r},'w').write(str(os.getpid()))\n"
                     "time.sleep(60)")
            job = subprocess.Popen([sys.executable, str(ROOT / "bounded_process.py"), "10",
                                    sys.executable, "-c", child], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            try:
                for _ in range(100):
                    if pidfile.exists():
                        break
                    time.sleep(.01)
                self.assertTrue(pidfile.exists())
                pid = int(pidfile.read_text())
                job.terminate()
                job.communicate(timeout=2)
                self.assertFalse(Path(f"/proc/{pid}").exists())
            finally:
                if job.poll() is None:
                    job.kill()
                job.communicate(timeout=2)

    def test_native_layout_fifo_timeout_and_recovery(self):
        helper = shutil.which("omarchy-hyprland-workspace-layout-current")
        if not helper:
            self.skipTest("Native Omarchy layout helper is not installed")
        with tempfile.TemporaryDirectory(dir="/tmp/opencode") as directory:
            base = Path(directory)
            modes = base / "omarchy/workspace-layouts"
            modes.mkdir(parents=True)
            mode = modes / "3.lua"
            os.mkfifo(mode)
            # Real native helper, only the compositor transport is a fixture.
            transport = base / "hyprctl"
            transport.write_text('#!/bin/sh\nprintf \'[{"id":3,"tiledLayout":"dwindle"}]\\n\'\n')
            transport.chmod(0o700)
            with patch.dict(os.environ, {"XDG_STATE_HOME": directory,
                                         "PATH": directory + os.pathsep + os.environ["PATH"]}):
                started = time.monotonic()
                with self.assertRaises(TimeoutError):
                    run([helper, "3"], timeout=.3)
                self.assertLess(time.monotonic() - started, 1.5)
                mode.unlink()
                mode.write_text('o.workspace_mode({workspace="3", mode = "floating"})\n')
                self.assertEqual(run([helper, "3"]).stdout.strip(), "floating")

    def test_all_finite_qml_jobs_use_supervisor(self):
        widget = (ROOT / "Workspaces.qml").read_text()
        resolver = (ROOT / "ApplicationResolver.qml").read_text()
        self.assertEqual(widget.count("  FiniteProcess {"), 3)
        self.assertEqual(resolver.count("  FiniteProcess {"), 2)
        self.assertEqual(widget.count("  Process {"), 1)  # persistent watcher
        self.assertIn('command: ["python3", root.actionScript, "watch-modes"]', widget)
        self.assertIn("timeoutSeconds: 15", widget)
        self.assertIn("processQuery.request.length > 24000", resolver)


if __name__ == "__main__":
    unittest.main()
