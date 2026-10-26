#!/usr/bin/env python3
"""Validate, then export with the installed Godot editor and export templates."""
import argparse
from pathlib import Path
import subprocess
import sys


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot",required=True)
    parser.add_argument("--target",choices=["android","windows"],default="android")
    parser.add_argument("--output",type=Path)
    args=parser.parse_args()
    project=Path(__file__).resolve().parents[1]
    check=subprocess.run([sys.executable,str(project/"tools/check-next.py"),"--godot",args.godot])
    if check.returncode:
        return check.returncode
    preset="Android" if args.target=="android" else "Windows Desktop"
    suffix="arm64.apk" if args.target=="android" else "x86_64.exe"
    output=(args.output or project/"builds"/f"LastCamp-v0.7.0-dev-{suffix}").resolve()
    output.parent.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([args.godot,"--headless","--path",str(project),"--export-debug",preset,str(output)])
    if result.returncode:
        return result.returncode
    if not output.is_file() or output.stat().st_size==0:
        print("Export produced no file",file=sys.stderr)
        return 1
    print(output)
    return 0

if __name__=="__main__":
    raise SystemExit(main())
