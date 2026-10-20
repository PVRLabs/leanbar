#!/usr/bin/env python3
"""Bounded argv invocation; emits a single JSON result for the AppKit host."""
import json
import os
import selectors
import signal
import subprocess
import sys
import time


def invoke(argv, timeout=5, limit=262144):
    child = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             start_new_session=True)
    poll = selectors.DefaultSelector()
    for stream in (child.stdout, child.stderr):
        os.set_blocking(stream.fileno(), False)
        poll.register(stream, selectors.EVENT_READ)
    output = {child.stdout: bytearray(), child.stderr: bytearray()}
    deadline = time.monotonic() + timeout
    error = None
    try:
        while poll.get_map():
            if time.monotonic() >= deadline:
                error = "timeout"
                break
            for key, _ in poll.select(min(.1, max(0, deadline-time.monotonic()))):
                data = os.read(key.fd, 8192)
                if not data:
                    poll.unregister(key.fileobj)
                else:
                    output[key.fileobj].extend(data)
                    if sum(map(len, output.values())) > limit:
                        error = "output limit"
                        break
            if error:
                break
        if not error:
            try:
                child.wait(timeout=max(.001, deadline-time.monotonic()))
            except subprocess.TimeoutExpired:
                error = "timeout"
    finally:
        # Also remove descendants that survived the producer or closed their pipes.
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        child.wait()
        poll.close()
        child.stdout.close()
        child.stderr.close()
    return dict(stdout=output[child.stdout][:limit].decode("utf-8", "replace"),
                stderr=output[child.stderr][:limit].decode("utf-8", "replace"),
                status=child.returncode, error=error)


if __name__ == "__main__":
    try:
        result = invoke(sys.argv[1:])
    except Exception as exc:
        result = dict(stdout="", stderr=str(exc), status=-1, error="launch failed")
    print(json.dumps(result))
