#!/bin/bash
# Run one headless test WITHOUT touching the real save: user:// is redirected to a throw-away folder.
#   tools/run_headless_test.sh <test name> [godot user args...]      e.g.  tools/run_headless_test.sh chapter7
# Needs GODOT=/path/to/godot (default: godot on PATH). Several can run at once (one folder per run).
# Most chapterN_test files overwrite user://veil_save.json; this keeps that away from the player's real save (VB-007).
set -e
T="$1"; shift || true
[ -n "$T" ] || { echo "usage: $0 <test name without _test.gd> [-- args]"; exit 2; }
GODOT="${GODOT:-godot}"
D="$(mktemp -d)"
trap 'rm -rf "$D"' EXIT
cd "$(dirname "$0")/.."
XDG_DATA_HOME="$D" "$GODOT" --headless --path . --fixed-fps 60 --script "res://game/tests/${T}_test.gd" "$@" 2>&1 | grep -E "^TEST|^RESULT|SCRIPT ERROR" || true
