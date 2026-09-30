#!/bin/sh
# Prints conky text for the speed/total line, following the default route.
# Used through ${execpi}, so the interface is re-detected on every refresh.
# CONKY_NET_INTERFACE=<iface> pins a fixed interface ("auto" or empty = follow).

iface=${CONKY_NET_INTERFACE:-}
if [ -z "$iface" ] || [ "$iface" = "auto" ]; then
    iface=$(ip route get 1.1.1.1 2>/dev/null |
        awk '/dev/{for (i=1;i<=NF;i++) if ($i == "dev") {print $(i+1); exit}}')
fi
[ -n "$iface" ] || iface=$(ip route show default 2>/dev/null | awk 'NR==1 {print $5}')
case "$iface" in
    ""|*[!A-Za-z0-9_.-]*) iface=lo ;;
esac

printf 'Down: ${downspeed %s} kb/s (${totaldown %s})  ${alignr}Up: ${upspeed %s} kb/s (${totalup %s})\n' \
    "$iface" "$iface" "$iface" "$iface"
