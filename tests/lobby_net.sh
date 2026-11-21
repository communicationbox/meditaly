#!/bin/bash
# Sala d'attesa in rete vera: chi ospita aspetta, l'amico entra e dice «pronto», si parte.
#   GODOT=/percorso/Godot tests/lobby_net.sh [cartella_log]
G="${GODOT:-/Applications/Godot 2.app/Contents/MacOS/Godot}"
L="${1:-$(mktemp -d)}"
PORT=27098
cd "$(dirname "$0")/.." || exit 1
"$G" --headless --path . -- --ospita --port $PORT --name Ospite --house 1 --test-lobby-host > "$L/host.log" 2>&1 &
HP=$!
trap 'kill $HP 2>/dev/null' EXIT
sleep 6
"$G" --headless --path . -- --connect 127.0.0.1 --port $PORT --name Amico --house 4 --test-lobby-client > "$L/client.log" 2>&1
RC=$?
wait $HP; RH=$?
grep "\[lobby\]" "$L/host.log"
grep "\[test\]" "$L/client.log"
ERR=$(cat "$L/host.log" "$L/client.log" | grep -c 'SCRIPT ERROR')
echo "client exit $RC, host exit $RH, errori di script: $ERR"
[ "$RC" = 0 ] && [ "$RH" = 0 ] && [ "$ERR" = 0 ]
