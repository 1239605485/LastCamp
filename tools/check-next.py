#!/usr/bin/env python3
"""Run the project's exploration tests with an installed Godot 4 executable."""
import argparse
import glob
import os
from pathlib import Path
import shutil
import subprocess
import sys

TESTS = [
    "test_exploration.gd", "test_free_gameplay.gd", "test_exploration_loop.gd",
    "test_pixel_ui.gd", "test_visual_assets_v06.gd", "test_touch_ui.gd",
    "test_road_profile.gd", "test_reference_layout.gd", "test_performance_budget.gd",
    "test_resource_cycle.gd", "test_reference_combat.gd", "test_resource_interruptions.gd", "test_seven_day_resources.gd",
]

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT"))
    args = parser.parse_args()
    engine = args.godot or shutil.which("godot4") or shutil.which("godot")
    if not engine and sys.platform=="win32":
        local_app=os.environ.get("LOCALAPPDATA", "")
        home=os.environ.get("USERPROFILE", "")
        candidates=glob.glob(str(Path(local_app)/"Programs/Godot/**/*console.exe"),recursive=True)
        candidates+=glob.glob(str(Path(home)/"scoop/apps/godot/current/*console.exe"))
        engine=next(iter(sorted(candidates,reverse=True)),None)
    if not engine:
        print("BLOCKED: Godot 4 not found. Pass --godot /path/to/Godot executable.", file=sys.stderr)
        return 2
    project = Path(__file__).resolve().parents[1]
    # The editor import step must precede runtime tests for freshly unpacked assets.
    commands = [[engine,"--headless","--editor","--path",str(project),"--import"]]
    commands += [[engine,"--headless","--path",str(project),"--script",f"tests/{name}"] for name in TESTS]
    for command in commands:
        print("RUN:", " ".join(map(str,command)), flush=True)
        try:
            result = subprocess.run(command, cwd=project, text=True, errors="replace", stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        except OSError as error:
            print(f"BLOCKED: cannot run Godot: {error}",file=sys.stderr)
            return 2
        print(result.stdout, end="", flush=True)
        # Some Godot script failures emit an error but still return exit code zero.
        if result.returncode or "SCRIPT ERROR:" in result.stdout or "Parse Error:" in result.stdout or "FAIL:" in result.stdout:
            return result.returncode or 1
    print(f"PASS: import and {len(TESTS)} test suites")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
