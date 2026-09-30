#!/bin/bash

KILLED=0
for PID in $(pgrep -x conky 2>/dev/null); do
    cmdline=$(tr '\0' ' ' < /proc/"$PID"/cmdline 2>/dev/null)
    if ! echo "$cmdline" | grep -q "conkyrc"; then
        kill "$PID" 2>/dev/null && KILLED=$((KILLED + 1))
    fi
done

if [ "$KILLED" -gt 0 ]; then
    echo "conky-window stopped"
else
    echo "conky-window: not running"
fi
