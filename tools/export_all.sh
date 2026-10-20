#!/usr/bin/env bash
# Exports release builds for Windows and Linux into build/.
# Usage: GODOT=/path/to/godot tools/export_all.sh
# Requires the Godot 4.3 export templates (Editor > Manage Export Templates).
set -euo pipefail
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
mkdir -p build/windows build/linux
"$GODOT" --headless --editor --path . --quit >/dev/null 2>&1 || true
"$GODOT" --headless --path . --export-release "Linux" build/linux/EndlessSiege.x86_64
"$GODOT" --headless --path . --export-release "Windows Desktop" build/windows/EndlessSiege.exe
ls -la build/windows build/linux
