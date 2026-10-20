#!/bin/bash
set -eu
cd -- "$(dirname -- "$0")"
app="$PWD/.build/LeanBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .build/module-cache
swiftc -O -module-cache-path "$PWD/.build/module-cache" src/main.swift -o "$app/Contents/MacOS/LeanBar"
cp src/invoke.py "$app/Contents/Resources/invoke.py"
/usr/bin/python3 - "$app" <<'PY_PLIST'
import pathlib, plistlib, sys
root = pathlib.Path(sys.argv[1])
(root / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='org.pvrlabs.leanbar', CFBundleName='LeanBar',
    CFBundleExecutable='LeanBar', CFBundlePackageType='APPL',
    CFBundleShortVersionString='0.1.0', CFBundleVersion='1',
    LSUIElement=True, NSHighResolutionCapable=True,
    NSHumanReadableCopyright='Copyright 2026 PVRLabs. MIT License.')))
PY_PLIST
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
