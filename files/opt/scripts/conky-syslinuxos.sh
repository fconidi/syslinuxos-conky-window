#!/bin/sh
# Prints the SYSLINUXOS conky block (pending updates, failed units, snapshots)
# on a single row. Used through ${execpi}; font sizes come from the launcher so
# they follow the auto-scaling (CONKY_F12 / CONKY_F10).

f12=${CONKY_F12:-12}
f10=${CONKY_F10:-10}
ok='${color 4d80df}'
warn='${color ffaa00}'
bad='${color ff4444}'

updates=$(apt-get -s upgrade 2>/dev/null | grep -c '^Inst')
failed=$(systemctl --failed --no-legend --plain 2>/dev/null | grep -c .)

printf '${font sans-serif:bold:size=%s}SYSLINUXOS ${hr 2}\n${font sans-serif:normal:size=%s}' "$f12" "$f10"

if [ "${updates:-0}" -gt 0 ]; then
    printf 'Updates: %s%s${color}' "$warn" "$updates"
else
    printf 'Updates: %s0${color}' "$ok"
fi

if [ "${failed:-0}" -gt 0 ]; then
    printf '${alignc}Failed: %s%s${color}' "$bad" "$failed"
else
    printf '${alignc}Failed: %s0${color}' "$ok"
fi

# Snapshots: only when snapper is readable by the current user
snaps=""
if command -v snapper >/dev/null 2>&1; then
    list=$(snapper -c root list 2>/dev/null) && \
        snaps=$(printf '%s\n' "$list" | awk -F'[ |]+' '$1 ~ /^[0-9]+$/ && $1 > 0' | wc -l)
fi
[ -n "$snaps" ] && printf '${alignr}Snapshots: %s' "$snaps"
printf '${alignr} \n${voffset 6}\n'
