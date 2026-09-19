# Wakey ⚡️

A sleek, lightweight macOS Menu Bar application and background daemon that keeps your MacBook awake when the lid is closed **only when connected to a power adapter (AC power)**. 

When on battery power, your Mac will sleep normally and safely as soon as the lid is closed, preventing overheating in your backpack.

---

## Features

- **Minimalist Status Menu Icon**:
  - Custom vector icon matching the app logo (side-view MacBook with lid half-closed).
  - **Awake on AC (Active)**: Half-closed MacBook with active screen glow and power indicator.
  - **On Battery (Standby)**: Half-closed MacBook outline (idle; will sleep on lid close).
  - **Disabled**: Flat closed MacBook (normal sleep behavior at all times).
  - **Warning**: Indicates helper service is stopped or needs installation.
- **Instant Real-Time Reaction**:
  - Automatically updates the menu bar and internal state the exact millisecond the power cable is plugged in or unplugged (powered by native `IOPSNotificationCreateRunLoopSource`).
- **Drag-and-Drop Installation**: Packaged as `Wakey.dmg` with an `/Applications` shortcut.
- **Self-Contained Helper Service**: Prompts to install the background service on first launch with a single macOS admin prompt—no Terminal required.
- **Uninstall Protection**: Includes an explicit confirmation dialog before removing the helper service.
- **Zero-impact Background Daemon**: Runs via `launchd` as a root daemon with practically 0% CPU usage.

---

## Installation via DMG (Recommended)

1. Build or open the DMG:
   ```bash
   make dmg
   open build/Wakey.dmg
   ```
2. Drag **`Wakey`** into the **Applications** shortcut folder.
3. Open **`Wakey`** from Applications (or Spotlight).
4. On first launch, click **Install** when prompted to enable the background service.

---

## How to Use It

1. **Working over SSH with the lid closed:**
   - Plug your MacBook into its charger.
   - The status icon immediately illuminates (Active).
   - Close the lid. Your Mac stays awake, Wi-Fi stays on, and you can SSH in anytime.

2. **On the go / Packing into a bag:**
   - Unplug the power adapter.
   - The status icon immediately switches to Standby.
   - Close the lid. Your Mac sleeps immediately, protecting your battery and preventing heat buildup.

3. **Temporarily disable the feature:**
   - Click the menu bar icon and uncheck **"Keep Awake on AC Power"**.
   - The icon changes to a closed laptop, and the Mac will sleep even when plugged in.

4. **Uninstall the Helper Service:**
   - Click the menu bar icon and select **"Uninstall Helper Service..."**.
   - A confirmation dialog will appear to verify before removing the service and restoring default macOS sleep settings.

---

## Development & Terminal Commands

```bash
make build       # Compile Wakey.app bundle
make dmg         # Build app and package as Wakey.dmg
make install     # Direct CLI install (requires sudo)
make uninstall   # Direct CLI uninstall (requires sudo)
make clean       # Remove build artifacts
```
