#!/usr/bin/env bash
# Two copies of the game on this computer play an online match over ENet: a host and a guest,
# each played by a bot, with bots filling the arena. Both print a NETTEST over line from their own
# copy of the match; they must match. Usage: tools/net_test.sh [log dir] [mode] [map]
cd "$(dirname "$0")/.."
DIR="${1:-/tmp/pa-net}"
MODE="${2:-tdm}"
MAP="${3:-}"
mkdir -p "$DIR"
EXTRA=""
if [ -n "$MAP" ]; then EXTRA=",map=$MAP"; fi
timeout 300 godot --headless --path . -- --net=host,start=2,bot,mode=$MODE,minutes=1$EXTRA > "$DIR/host.txt" 2>&1 &
sleep 3
timeout 300 godot --headless --path . -- --net=join=127.0.0.1,bot > "$DIR/guest.txt" 2>&1
wait
grep -h "NETTEST\|SCRIPT ERROR" "$DIR/host.txt" | sed 's/^/host:  /'
grep -h "NETTEST\|SCRIPT ERROR" "$DIR/guest.txt" | sed 's/^/guest: /'
