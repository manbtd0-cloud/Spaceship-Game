#!/usr/bin/env bash
set -euo pipefail

GODOT_BIN="${GODOT_BIN:-godot}"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
    printf 'ERROR: Godot executable not found: %s\n' "$GODOT_BIN" >&2
    printf 'Set GODOT_BIN to the Godot 4.7.1 executable path.\n' >&2
    exit 127
fi

"$GODOT_BIN" --headless --path . --editor --quit
"$GODOT_BIN" --headless --path . --script res://tests/test_runner.gd
"$GODOT_BIN" --headless --path . --quit-after 2
