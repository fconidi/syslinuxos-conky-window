#!/bin/sh

set -u

cpu_temp() {
    value=$(sensors 2>/dev/null |
        grep -m1 -E '^(Package id 0|Tctl|Tdie):' |
        grep -oE '\+[0-9]+(\.[0-9]+)?°C' |
        head -1 |
        tr -d '+°C')
    [ -n "$value" ] && printf '%s' "$value" || printf 'N/A'
}

gpu_temp() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        value=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null | head -1)
    else
        value=$(sensors 2>/dev/null |
            grep -m1 -E 'edge:|junction:' |
            grep -oE '[0-9]+(\.[0-9]+)?' |
            head -1)
    fi
    case "$value" in
        ""|*[!0-9.]*) printf 'N/A' ;;
        *) printf '%s°C' "$value" ;;
    esac
}

fan_speed() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        value=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader 2>/dev/null | head -1)
    else
        value=$(sensors 2>/dev/null | grep -m1 -E 'fan[0-9]+:' | awk '{print $2}')
    fi
    [ -n "$value" ] && printf '%s' "$value" || printf 'N/A'
}

gpu_available() {
    if command -v nvidia-smi >/dev/null 2>&1 ||
        [ -r /sys/class/drm/card0/device/gpu_busy_percent ]; then
        printf '1'
    else
        printf '0'
    fi
}

fan_available() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        value=$(nvidia-smi --query-gpu=fan.speed --format=csv,noheader 2>/dev/null | head -1)
        [ -n "$value" ] && [ "$value" != "N/A" ] && printf '1' || printf '0'
        return
    fi
    sensors 2>/dev/null | grep -q -E 'fan[0-9]+:' && printf '1' || printf '0'
}

case "${1:-}" in
    cpu_temp) cpu_temp ;;
    gpu_temp) gpu_temp ;;
    fan_speed) fan_speed ;;
    gpu_available) gpu_available ;;
    fan_available) fan_available ;;
    *) printf 'N/A' ;;
esac
