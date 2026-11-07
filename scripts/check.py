#!/usr/bin/env python3
"""Project gates, cheapest first: rojo build (both places), lune tests, selene, stylua.

    python scripts/check.py        run every gate
    python scripts/check.py --fix  let stylua rewrite instead of failing

Output lands in build/Hub.rbxl and build/Mission.rbxl; open those in Studio to playtest.
"""
import argparse
import subprocess
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8", errors="replace")
ROOT = Path(__file__).resolve().parent.parent


def run(name, cmd):
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8", errors="replace")
    ok = p.returncode == 0
    print(f"  {'PASS' if ok else 'FAIL'}  {name}")
    out = ((p.stdout or "") + (p.stderr or "")).strip()
    if out and (not ok or name.startswith("lune")):
        for line in out.splitlines()[-40:]:
            print(f"        {line}")
    return ok


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--fix", action="store_true")
    a = ap.parse_args()
    (ROOT / "build").mkdir(exist_ok=True)
    for name, cmd in [
        ("rojo build hub", ["rojo", "build", "hub.project.json", "-o", "build/Hub.rbxl"]),
        ("rojo build mission", ["rojo", "build", "mission.project.json", "-o", "build/Mission.rbxl"]),
    ]:
        if not run(name, cmd):
            return 1
    results = [
        run("lune tests", ["lune", "run", "test"]),
        run("selene", ["selene", "src"]),
        run("stylua", ["stylua"] + ([] if a.fix else ["--check"]) + ["src", "tests", "lune"]),
    ]
    print("all gates green" if all(results) else "gates FAILED")
    return 0 if all(results) else 1


if __name__ == "__main__":
    sys.exit(main())
