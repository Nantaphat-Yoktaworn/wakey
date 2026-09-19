# Lid Sleep Manager

A lightweight macOS Menu Bar application and background daemon that keeps your MacBook awake when the lid is closed **only when connected to a power adapter (AC power)**. 

When on battery power, your Mac will sleep normally and safely as soon as the lid is closed.

---

## Features

- **Menu Bar Indicator & Toggle**:
  - ⚡️ **Active (`bolt.fill`)**: Mac is plugged in; sleep is disabled when the lid is closed. SSH remains available.
  - 🔋 **Standby (`battery.100`)**: Running on battery; normal sleep behavior is active to prevent overheating in a bag.
  - 💤 **Disabled (`moon.zzz.fill`)**: Feature is manually turned off; normal sleep behavior is active at all times.
  - ⚠️ **Warning (`exclamationmark.triangle.fill`)**: Background helper service is not running or needs installation.
- **Drag-and-Drop Installation**: Packaged as a `.dmg` with an `/Applications` shortcut.
- **Self-Contained Helper Installer**: Prompts to install the background service on first launch—no need to use the Terminal.
- **Zero-impact Background Daemon**: Runs via `launchd`, reacts to power changes, and only applies power management changes when necessary.
- **Clean Uninstallation**: Built-in option inside the app menu (and script) cleanly unloads the daemon, removes all files, and restores default macOS sleep behavior.

---

## Installation via DMG (Recommended)

1. Build or open the DMG:
   ```bash
   make dmg
   open build/LidSleepManager.dmg
   ```
2. Drag **`LidSleepManager`** into the **Applications** shortcut folder.
3. Open **`LidSleepManager`** from Applications (or Spotlight).
4. On first launch, click **Install** when prompted to install the background service (enter your macOS password once).

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

4. **Uninstall the Helper Service:**
   - Click the menu bar icon and select **"Uninstall Helper Service..."**.
   - Your Mac immediately reverts to default factory sleep behavior.

---

## Development & Terminal Commands

```bash
make build       # Compile app bundle
make dmg         # Build app and package as DMG
make install     # Direct CLI install (requires sudo)
make uninstall   # Direct CLI uninstall (requires sudo)
make clean       # Remove build artifacts
```
