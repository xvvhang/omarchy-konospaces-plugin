"""Finite native jobs: wall-clock deadline, streaming byte caps and group cleanup.

Only the outer job creates a session. Nested helper calls stay in that session,
so terminating the job also terminates native shell-helper descendants.
"""
import os
import selectors
import signal
import subprocess
import sys
import time

STDOUT_LIMIT = 1024 * 1024
STDERR_LIMIT = 16 * 1024


def run(command, timeout=4, *, own_group=True):
    deadline = time.monotonic() + timeout
    output = [bytearray(), bytearray()]
    process = subprocess.Popen(command, stdin=subprocess.DEVNULL,
                               stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                               start_new_session=own_group)
    def terminate():
        try:
            if own_group:
                os.killpg(process.pid, signal.SIGKILL)
            elif process.poll() is None:
                process.kill()
        except ProcessLookupError:
            pass

    previous = {}
    def interrupted(signum, frame):
        raise RuntimeError("Finite job cancelled")

    try:
        if own_group:
            for signum in (signal.SIGTERM, signal.SIGINT, signal.SIGHUP):
                previous[signum] = signal.signal(signum, interrupted)
        with selectors.DefaultSelector() as selector:
            for index, stream in enumerate((process.stdout, process.stderr)):
                os.set_blocking(stream.fileno(), False)
                selector.register(stream, selectors.EVENT_READ, index)
            while selector.get_map() or process.poll() is None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise TimeoutError("Finite job deadline exceeded")
                for key, _ in selector.select(min(remaining, 0.05)):
                    data = os.read(key.fd, 65536)
                    if not data:
                        selector.unregister(key.fileobj)
                        continue
                    index = key.data
                    limit = STDOUT_LIMIT if index == 0 else STDERR_LIMIT
                    if len(output[index]) + len(data) > limit:
                        raise RuntimeError("Finite job output limit exceeded")
                    output[index].extend(data)
            code = process.wait(timeout=max(0.001, deadline - time.monotonic()))
        stdout, stderr = (bytes(value).decode("utf-8", errors="replace") for value in output)
        if code != 0:
            raise RuntimeError("Finite job exited with code " + str(code) + ": " + stderr[:4096])
        return subprocess.CompletedProcess(command, code, stdout, stderr)
    finally:
        # Also remove descendants that outlive a successfully exited parent.
        terminate()
        process.stdout.close()
        process.stderr.close()
        process.wait(timeout=1)
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def main():
    try:
        timeout = float(sys.argv[1])
        if not 0 < timeout <= 30 or len(sys.argv) < 3:
            raise ValueError("Invalid finite job")
        result = run(sys.argv[2:], timeout)
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        return 0
    except (ValueError, OSError, RuntimeError, subprocess.SubprocessError) as error:
        print(str(error)[:4096], file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
