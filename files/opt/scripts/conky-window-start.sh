#!/bin/bash

REF_W=1920
REF_H=1080
CONF_SRC=/etc/conky/conky-window.conf
CONF_TMP=/tmp/conky-window-scaled.conf

# Detect current screen resolution
SCREEN_W=""
SCREEN_H=""
if command -v xrandr >/dev/null 2>&1; then
    RES=$(xrandr 2>/dev/null | grep '\*' | head -1 | awk '{print $1}')
    SCREEN_W=${RES%x*}
    SCREEN_H=${RES#*x}
fi
if [ -z "$SCREEN_W" ] && command -v xdpyinfo >/dev/null 2>&1; then
    RES=$(xdpyinfo 2>/dev/null | grep 'dimensions' | awk '{print $2}')
    SCREEN_W=${RES%x*}
    SCREEN_H=${RES#*x}
fi
SCREEN_W=${SCREEN_W:-$REF_W}
SCREEN_H=${SCREEN_H:-$REF_H}

NET_IFACE=${CONKY_NET_INTERFACE:-}
if [ -z "$NET_IFACE" ] || [ "$NET_IFACE" = "auto" ]; then
    NET_IFACE=$(ip route get 1.1.1.1 2>/dev/null |
        awk '/dev/{for (i=1;i<=NF;i++) if ($i == "dev") {print $(i+1); exit}}')
fi
if [ -z "$NET_IFACE" ]; then
    NET_IFACE=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')
fi
case "$NET_IFACE" in
    ""|*[!A-Za-z0-9_.-]*) NET_IFACE=lo ;;
esac

# Scale factor: min(W/REF_W, H/REF_H). Override: CONKY_WINDOW_SCALE=<factor>
if [ -n "$CONKY_WINDOW_SCALE" ]; then
    SCALE=$CONKY_WINDOW_SCALE
else
    SCALE=$(awk -v w="$SCREEN_W" -v h="$SCREEN_H" -v rw="$REF_W" -v rh="$REF_H" \
        'BEGIN { sx=w/rw; sy=h/rh; s=(sx<sy)?sx:sy; printf "%.4f", s }')
fi

# Scale integer value with minimum floor
scale_val() {
    local orig=$1 min=${2:-1}
    awk -v s="$SCALE" -v orig="$orig" -v mn="$min" \
        'BEGIN { v=int(orig*s+0.5); if(v<mn)v=mn; print v }'
}

F16=$(scale_val 16 8)
F12=$(scale_val 12 7)
F10=$(scale_val 10 7)
MIN_W=$(scale_val 300 150)
GAP_Y=$(scale_val 30 10)
GH=$(scale_val 22 12)
GW150=$(scale_val 150 75)
GW180=$(scale_val 180 90)
CBAR_H=$(scale_val 8 4)
CBAR_W=$(scale_val 128 60)     # single-column bar width

# Adaptive layout based on CPU count:
#   <=6  → single column + TOP 3
#   7-12 → two columns  + TOP 1
#   >12  → two columns  + TOP 1
NCPU=$(nproc)

if [ "$NCPU" -le 6 ]; then
    TOP_N=3
else
    TOP_N=1
fi

# Generate CPU bar lines
#   <=6 threads : one column
#   7-12        : two columns
#   >12         : ceil(threads/8) columns (at most 8 rows), narrower bars
CPU_BARS_FILE=$(mktemp)
if [ "$NCPU" -le 6 ]; then
    for i in $(seq 1 "$NCPU"); do
        echo "\${color 6699dd}${i}\${color} \${cpubar ${CBAR_H},${CBAR_W} cpu${i}} \${alignr}\${cpu cpu${i}}%" \
            >> "$CPU_BARS_FILE"
    done
else
    if [ "$NCPU" -le 12 ]; then
        COLS=2
    else
        COLS=$(( (NCPU + 7) / 8 ))
    fi
    ROWS=$(( (NCPU + COLS - 1) / COLS ))
    PITCH=$(scale_val $(( 310 / COLS )) 40)         # distance between column starts
    BARW=$(( PITCH - $(scale_val 67 30) ))          # label + percentage + gaps
    [ "$BARW" -lt 12 ] && BARW=12
    for r in $(seq 1 "$ROWS"); do
        line=""
        for c in $(seq 0 $((COLS - 1))); do
            idx=$(( r + c * ROWS ))
            [ "$idx" -le "$NCPU" ] || continue
            [ "$c" -gt 0 ] && line="${line}\${goto $(( PITCH * c ))}"
            line="${line}\${color 6699dd}${idx}\${color} \${cpubar ${CBAR_H},${BARW} cpu${idx}} \${cpu cpu${idx}}%"
        done
        echo "$line" >> "$CPU_BARS_FILE"
    done
fi

# Generate TOP rows
TOP_ROWS_FILE=$(mktemp)
for i in $(seq 1 "$TOP_N"); do
    printf "\${top name %d} \${alignr}\${top cpu %d}%%  \${top mem %d}%%\n" \
        "$i" "$i" "$i" >> "$TOP_ROWS_FILE"
done

# Optional hardware rows are inserted only when the metric exists.  This
# keeps the window height compact on systems without a discrete GPU or fan.
GPU_ROW_FILE=$(mktemp)
FAN_ROW_FILE=$(mktemp)
if [ "$(/opt/scripts/conky-hardware.sh gpu_available 2>/dev/null)" = "1" ]; then
    printf '%s\n' 'GPU: ${alignr}${execi 5 /opt/scripts/conky-hardware.sh gpu_temp}' > "$GPU_ROW_FILE"
fi
if [ "$(/opt/scripts/conky-hardware.sh fan_available 2>/dev/null)" = "1" ]; then
    printf '%s\n' 'Fan: ${alignr}${execi 5 /opt/scripts/conky-hardware.sh fan_speed}' > "$FAN_ROW_FILE"
fi

# / and /home on the same filesystem (btrfs subvolumes) report identical usage:
# show a single row.
src_of() { findmnt -no SOURCE -T "$1" 2>/dev/null | sed 's/\[.*\]$//'; }
ROOT_SRC=$(src_of /)
HOME_SRC=$(src_of /home)
HOME_ROWS_FILE=$(mktemp)
if [ -n "$ROOT_SRC" ] && [ "$ROOT_SRC" = "$HOME_SRC" ]; then
    ROOT_LABEL="ROOT+HOME"
else
    ROOT_LABEL="ROOT"
    cat > "$HOME_ROWS_FILE" <<'HOMEEOF'
HOME $alignc ${fs_used /home} / ${fs_size /home} $alignr ${fs_used_perc /home}%
${if_match ${fs_used_perc /home}>80}${color ff4444}${else}${if_match ${fs_used_perc /home}>60}${color ffaa00}${else}${color 4d80df}${endif}${endif}${fs_bar /home}${color}
HOMEEOF
fi

# CPU temperature row only when a numeric value is available (no sensors in
# VMs/containers: the comparison would fail on every refresh).
TEMP_ROW_FILE=$(mktemp)
case "$(/opt/scripts/conky-hardware.sh cpu_temp 2>/dev/null)" in
    ""|*[!0-9.]*) ;;
    *)
        cat > "$TEMP_ROW_FILE" <<'TEMPEOF'
${if_match ${execi 3 /opt/scripts/conky-hardware.sh cpu_temp}>=85}${color ff4444}${else}${if_match ${execi 3 /opt/scripts/conky-hardware.sh cpu_temp}>=70}${color ffaa00}${else}${color 4d80df}${endif}${endif}Temp: ${alignr}${execi 3 /opt/scripts/conky-hardware.sh cpu_temp}°C${color}
TEMPEOF
        ;;
esac

# Step 1: inject CPU bars and TOP rows in place of placeholders
awk -v bars="$CPU_BARS_FILE" -v top="$TOP_ROWS_FILE" \
    -v gpu="$GPU_ROW_FILE" -v fan="$FAN_ROW_FILE" \
    -v home="$HOME_ROWS_FILE" -v temp="$TEMP_ROW_FILE" '
/__CPU_BARS__/ {
    while ((getline line < bars) > 0) print line
    close(bars); next
}
/__TOP_ROWS__/ {
    while ((getline line < top) > 0) print line
    close(top); next
}
/__GPU_ROW__/ {
    while ((getline line < gpu) > 0) print line
    close(gpu); next
}
/__FAN_ROW__/ {
    while ((getline line < fan) > 0) print line
    close(fan); next
}
/__TEMP_ROW__/ {
    while ((getline line < temp) > 0) print line
    close(temp); next
}
/__HOME_ROWS__/ {
    while ((getline line < home) > 0) print line
    close(home); next
}
{ print }
' "$CONF_SRC" > "${CONF_TMP}.tmp"
# Above 12 threads the CPU bars take more rows: drop the TOP section (the ring
# theme already lists the heaviest processes) so the NETWORK block stays visible.
if [ "$NCPU" -gt 12 ]; then
    sed -i '/__TOP_BEGIN__/,/__TOP_END__/d' "${CONF_TMP}.tmp"
else
    sed -i '/__TOP_BEGIN__\|__TOP_END__/d' "${CONF_TMP}.tmp"
fi

rm -f "$CPU_BARS_FILE" "$TOP_ROWS_FILE" "$GPU_ROW_FILE" "$FAN_ROW_FILE" "$HOME_ROWS_FILE" "$TEMP_ROW_FILE"

# Step 2: apply scaling (placeholder trick avoids chained replacements)
sed \
    -e "s/size=16/__SZ16__/g" \
    -e "s/size=12/__SZ12__/g" \
    -e "s/size=10/__SZ10__/g" \
    -e "s/__SZ16__/size=${F16}/g" \
    -e "s/__SZ12__/size=${F12}/g" \
    -e "s/__SZ10__/size=${F10}/g" \
    -e "s/minimum_width = 300/minimum_width = ${MIN_W}/" \
    -e "s/gap_y = 30/gap_y = ${GAP_Y}/" \
    -e "s/__NET_IFACE__/${NET_IFACE}/g" \
    -e "s/__ROOT_LABEL__/${ROOT_LABEL}/g" \
    -e "s/30,150/${GH},${GW150}/g" \
    -e "s/30,180/${GH},${GW180}/g" \
    "${CONF_TMP}.tmp" > "$CONF_TMP"
rm -f "${CONF_TMP}.tmp"

export CONKY_F12="$F12" CONKY_F10="$F10"
conky --daemonize --pause=1 --config "$CONF_TMP"
