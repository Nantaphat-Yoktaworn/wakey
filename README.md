# Lid Sleep Manager

A lightweight macOS Menu Bar application and background daemon that keeps your MacBook awake when the lid is closed **only when connected to a power adapter (AC power)**. 

When on battery power, your Mac will sleep normally and safely as soon as the lid is closed.

---

## Features

- **Menu Bar Indicator & Toggle**:
  - ⚡️ **Active (`bolt.fill`)**: Mac is plugged in; sleep is disabled when the lid is closed. SSH remains available.
  - 🔋 **Standby (`battery.100`)**: Running on battery; normal sleep behavior is active to prevent overheating in a bag.
  - 💤 **Disabled (`moon.zzz.fill`)**: Feature is manually turned off; normal sleep behavior is active at all times.
- **Toggle without `sudo`**: The menu bar app communicates with the background daemon via a state file, so clicking the toggle doesn't prompt you for a password.
- **Zero-impact Background Daemon**: Runs via `launchd`, reacts to power changes, and only applies power management changes when necessary.
- **Clean Uninstaller**: One command cleanly unloads the daemon, removes all files, and restores default macOS sleep behavior.

---

## Project Structure

```
lid-sleep-manager/
├── App/
│   ├── main.swift             # Native macOS Swift Menu Bar app
│   └── Info.plist             # App metadata (LSUIElement = true)
├── Daemon/
│   ├── lid-sleep-daemon.sh    # Background shell script managing pmset
│   └── com.lidsleepmanager.daemon.plist  # launchd service definition
├── Scripts/
│   ├── build.sh               # Compiles the Swift menu bar app
│   ├── install.sh             # Installs the app and daemon (requires sudo)
│   └── uninstall.sh           # Uninstalls app & daemon, reverts pmset
├── Makefile                   # Quick commands
└── README.md
```

---

## Quick Start

### 1. Build and Install
Run the following from the project root:

```bash
make install
```
*(Or manually: `sudo ./Scripts/install.sh`)*

This will:
1. Compile the Swift app into `/Applications/LidSleepManager.app`.
2. Install the daemon script to `/usr/local/bin/lid-sleep-daemon.sh`.
3. Set up `/Library/Application Support/LidSleepManager/enabled`.
4. Register and start the background service with `launchd`.

### 2. Launch the Menu Bar App
Launch the app from `/Applications`:
```bash
open /Applications/LidSleepManager.app
```
You will see the icon appear in your macOS status menu bar.

---

## How to Use It

1. **Working over SSH with the lid closed:**
   - Plug your MacBook into its charger.
   - The menu bar icon changes to ⚡️ (Active).
   - Close the lid. Your Mac stays awake, Wi-Fi stays on, and you can SSH in anytime.

2. **On the go / Packing into a bag:**
   - Unplug the power adapter.
   - The menu bar icon changes to 🔋 (Standby).
   - Close the lid. Your Mac sleeps immediately, protecting your battery and preventing overheating.

3. **Temporarily disable the feature:**
   - Click the menu bar icon and uncheck **"Keep Awake on AC Power"**.
   - The icon changes to 💤 (Disabled) and the Mac will sleep even when plugged in.

---

## Uninstallation

To remove everything and return your Mac to 100% factory default power behavior:

```bash
make uninstall
```
*(Or manually: `sudo ./Scripts/uninstall.sh`)*
