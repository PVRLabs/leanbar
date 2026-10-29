#!/bin/bash
set -eu
cd -- "$(dirname -- "$0")"
app="$PWD/.build/LeanBar.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" .build/module-cache
if [ "$#" -eq 1 ] && [ "$1" = "--universal" ]; then
    for arch in arm64 x86_64; do
        swiftc -O -target "$arch-apple-macosx13.0" -module-cache-path "$PWD/.build/module-cache" src/main.swift -o ".build/LeanBar-$arch"
    done
    lipo -create .build/LeanBar-arm64 .build/LeanBar-x86_64 -output "$app/Contents/MacOS/LeanBar"
elif [ "$#" -eq 0 ]; then
    swiftc -O -module-cache-path "$PWD/.build/module-cache" src/main.swift -o "$app/Contents/MacOS/LeanBar"
else
    printf 'usage: %s [--universal]\n' "$0" >&2
    exit 2
fi
cp src/invoke.py "$app/Contents/Resources/invoke.py"
cp LICENSE "$app/Contents/Resources/LICENSE"
cp examples/menu.sh "$app/Contents/Resources/menu.sh"
/usr/bin/python3 - "$app" <<'PY_PLIST'
import pathlib, plistlib, sys
root = pathlib.Path(sys.argv[1])
(root / 'Contents/Info.plist').write_bytes(plistlib.dumps(dict(
    CFBundleIdentifier='org.pvrlabs.leanbar', CFBundleName='LeanBar',
    CFBundleExecutable='LeanBar', CFBundlePackageType='APPL',
    CFBundleShortVersionString='0.1.2-dev', CFBundleVersion='3',
    LSMinimumSystemVersion='13.0',
    LSUIElement=True, NSHighResolutionCapable=True,
    NSHumanReadableCopyright='Copyright 2026 PVRLabs. MIT License.')))
PY_PLIST
codesign --force --sign - "$app"
printf 'Built %s\n' "$app"
