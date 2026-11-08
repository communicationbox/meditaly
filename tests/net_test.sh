#!/bin/bash
# Test di rete reale: server headless + 2 client (uno entra a partita iniziata).
# Controlla che i mondi restino identici byte per byte mentre tutto crolla.
#   GODOT=/percorso/Godot tests/net_test.sh [cartella_log]
G="${GODOT:-/Applications/Godot 2.app/Contents/MacOS/Godot}"
L="${1:-$(mktemp -d)}"
PORT=27099
cd "$(dirname "$0")/.." || exit 1
"$G" --headless --path . -- --test-server --port $PORT > "$L/server.log" 2>&1 &
SP=$!
trap 'kill $SP 2>/dev/null' EXIT
sleep 5
"$G" --headless --path . -- --connect 127.0.0.1 --port $PORT --test-client --house 0 --name Alice > "$L/c1.log" 2>&1 &
C1=$!
sleep 22
"$G" --headless --path . -- --connect 127.0.0.1 --port $PORT --test-client --house 5 --name Bruno > "$L/c2.log" 2>&1 &
C2=$!
wait $C2; R2=$?
wait $C1; R1=$?
echo "client1: $(grep RISULTATO "$L/c1.log") (exit $R1)"
echo "client2: $(grep RISULTATO "$L/c2.log") (exit $R2)"
ERR=$(cat "$L/server.log" "$L/c1.log" "$L/c2.log" | grep -c 'SCRIPT ERROR')
echo "errori di script: $ERR"
[ "$R1" = 0 ] && [ "$R2" = 0 ] && [ "$ERR" = 0 ]
