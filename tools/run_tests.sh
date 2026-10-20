#!/usr/bin/env bash
# Runs the headless test suite. Fails on test failures AND on any GDScript runtime error
# (GDScript has no exceptions, so runtime errors are detected from the log).
# Usage: GODOT=/path/to/godot tools/run_tests.sh [name_filter]
set -u
GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.."
"$GODOT" --headless --editor --path . --quit >/dev/null 2>&1   # (re)import resources
LOG="$(mktemp)"
TEST_FILTER="${1:-}" "$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1 | tee "$LOG"
STATUS=${PIPESTATUS[0]}
if grep -q "SCRIPT ERROR" "$LOG"; then
	echo "FAILED: GDScript runtime errors found in the log"
	STATUS=1
fi
rm -f "$LOG"
exit "$STATUS"
