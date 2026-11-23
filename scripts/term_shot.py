#!/usr/bin/env python3
"""Screenshots of a real terminal running a real command.

An xterm on a virtual X display (Xvfb) shows the prompt and the command, runs
it in the repository, and stays open when it ends; ImageMagick `import` then
saves the xterm window (the last screenful of output, with the exit status).

Library:
  with Terminal() as term:
      rc = term.run("make unit", "results/unit/terminal_unit.png", rows=40)
CLI:
  term_shot.py OUT.png -- COMMAND ...       (--rows N --cols N)
Needs: Xvfb, xterm, ImageMagick (import), x11-utils (xdpyinfo, xwininfo).
"""
import argparse
import os
import re
import shlex
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


class Terminal:
    def __init__(self, display=":88", width=1900, height=1300):
        self.display, self.w, self.h = display, width, height
        self.env = dict(os.environ, DISPLAY=display, LANG="C.UTF-8", LC_ALL="C.UTF-8",
                        GDK_BACKEND="x11", TERM="xterm-256color")
        self.env.pop("WAYLAND_DISPLAY", None)
        self.tmp = Path(tempfile.mkdtemp(prefix="termshot_"))

    def __enter__(self):
        self.xvfb = subprocess.Popen(["Xvfb", self.display, "-screen", "0", f"{self.w}x{self.h}x24",
                                      "-nolisten", "tcp"], stdout=subprocess.DEVNULL,
                                     stderr=subprocess.DEVNULL)
        for _ in range(50):
            if subprocess.run(["xdpyinfo"], env=self.env, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL).returncode == 0:
                return self
            time.sleep(0.1)
        raise RuntimeError("Xvfb did not start")

    def __exit__(self, *exc):
        self.xvfb.terminate()
        self.xvfb.wait(10)

    def run(self, command, out_png, rows=45, cols=150, timeout=7200, title=None):
        """Run `command` (shell syntax) in an xterm in ROOT; screenshot when it ends.
        Returns the command's exit status."""
        done = self.tmp / f"done_{time.time_ns()}"
        user = os.environ.get("USER", "user")
        host = os.uname().nodename
        prompt = f"{user}@{host}:~/{ROOT.name}$ "
        script = (f"cd {shlex.quote(str(ROOT))}; printf '%s%s\\n' {shlex.quote(prompt)} "
                  f"{shlex.quote(command)}; {command}; rc=$?; "
                  f"printf '\\n%s(exit status %d)\\n' {shlex.quote(prompt)} $rc; "
                  f"echo $rc > {shlex.quote(str(done))}; sleep 100000")
        p = subprocess.Popen(
            ["xterm", "-geometry", f"{cols}x{rows}+0+0", "-fa", "DejaVu Sans Mono", "-fs", "10",
             "-bg", "white", "-fg", "black", "-u8", "-xrm", "XTerm*saveLines: 20000",
             "-T", title or command, "-e", "bash", "-c", script],
            env=self.env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            start_new_session=True)
        try:
            t_end = time.time() + timeout
            while not done.exists():
                if time.time() > t_end:
                    raise RuntimeError(f"timeout: {command}")
                if p.poll() is not None:
                    raise RuntimeError(f"xterm exited early: {command}")
                time.sleep(1)
            rc = int(done.read_text().strip() or 1)
            time.sleep(1.5)                      # let xterm draw the last lines
            tree = subprocess.run(["xwininfo", "-root", "-tree"], env=self.env,
                                  capture_output=True, text=True).stdout
            m = re.search(r"^\s*(0x[0-9a-f]+) \"" + re.escape((title or command)[:20]), tree, re.M)
            win = m.group(1) if m else "root"
            Path(out_png).parent.mkdir(parents=True, exist_ok=True)
            subprocess.run(["import", "-window", win, str(out_png)], env=self.env, check=True)
        finally:
            os.killpg(p.pid, 15)
            p.wait(10)
        return rc


def main():
    argv = sys.argv[1:]
    if "--" not in argv:
        sys.exit("usage: term_shot.py OUT.png [--rows N] [--cols N] -- COMMAND ...")
    k = argv.index("--")
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("out")
    ap.add_argument("--rows", type=int, default=45)
    ap.add_argument("--cols", type=int, default=150)
    a = ap.parse_args(argv[:k])
    cmd = argv[k + 1:]
    with Terminal() as t:
        sys.exit(t.run(" ".join(cmd), a.out, rows=a.rows, cols=a.cols))


if __name__ == "__main__":
    main()
