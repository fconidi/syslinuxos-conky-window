# syslinuxos-conky-window

Conky system-monitor panel for [SysLinuxOS](https://syslinuxos.com), docked on the right side of the desktop.

Shows system info, CPU (temperature, optional GPU/fan, per-core bars), top processes, memory, file system, a SYSLINUXOS status row (pending updates, failed units, snapshots when readable) and network (IPs, ISP, speed and totals, graphs).

## Features

- **Auto-scaling** of fonts, widths and bars to the screen resolution (reference 1920x1080). Override with `CONKY_WINDOW_SCALE=<n>`.
- **CPU bars generated for any number of logical processors**; the layout adapts (one or two columns, number of TOP rows).
- **Network interface follows the default route**, re-detected every 10 seconds. Pin one with `CONKY_NET_INTERFACE=<iface>`. The two speed graphs stay on the interface detected at startup.
- **Single ROOT+HOME row** when `/` and `/home` are on the same file system (btrfs subvolumes).
- **Optional rows only when available**: GPU temperature (nvidia-smi or sensors), fan speed.
- **SYSLINUXOS row**: pending APT updates, failed systemd units, and the snapper snapshot count when `snapper list` is readable by the user.

## Install

From the SysLinuxOS APT repository:

```
sudo apt install conky-window
```

or from a release `.deb`:

```
sudo apt install ./conky-window_<version>_all.deb
```

Start and stop from **Menu > System > Monitor** (Conky-window-start / Conky-window-stop).

## Build

```
bash build-deb.sh
```

Produces `conky-window_<version>_all.deb` (no sudo, uses fakeroot).

## Author / License

**Franco Conidi** (aka *edmond*) — <fconidi@gmail.com> — <https://syslinuxos.com> — <https://francoconidi.it>

GPL-3.0+, see `files/usr/share/doc/conky-window/copyright`.
