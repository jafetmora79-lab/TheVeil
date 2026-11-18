#!/bin/bash
# Compile-check the URSC shaders on a software GL driver (no screenshots). Needs xvfb-run and GODOT=<binary>.
# Prints the number of SHADER ERROR lines (0 = all compile). user:// goes to a throw-away folder.
cd "$(dirname "$0")/.."
D="$(mktemp -d)"; trap 'rm -rf "$D"' EXIT
XDG_DATA_HOME="$D" "${GODOT:-godot}" --headless --path . --import >/dev/null 2>&1
XDG_DATA_HOME="$D" xvfb-run -a "${GODOT:-godot}" --path . --rendering-driver opengl3 --script res://game/tests/ursc_shaders_check.gd --quit-after 600 > "$D/log" 2>&1
grep -E "^URSC|SHADER ERROR" "$D/log"
echo "shader errors: $(grep -c 'SHADER ERROR' "$D/log")"
