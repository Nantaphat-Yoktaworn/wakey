import Cocoa
import IOKit.ps

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var updateTimer: Timer?
    
    private let stateDir = "/Library/Application Support/LidSleepManager"
    private let stateFile = "/Library/Application Support/LidSleepManager/enabled"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Initial setup
        updateStatus()
        
        // Periodically refresh status every 3 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
    }
    
    // Check if the toggle is enabled in the state file
    private func isFeatureEnabled() -> Bool {
        guard let content = try? String(contentsOfFile: stateFile, encoding: .utf8) else {
            return false
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines) == "1"
    }
    
    // Update the state file
    private func setFeatureEnabled(_ enabled: Bool) {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: stateDir) {
            try? fileManager.createDirectory(atPath: stateDir, withIntermediateDirectories: true, attributes: [
                .posixPermissions: 0o777
            ])
        }
        
        let value = enabled ? "1\n" : "0\n"
        try? value.write(toFile: stateFile, atomically: true, encoding: .utf8)
        
        // Ensure permissions allow reading/writing
        try? fileManager.setAttributes([.posixPermissions: 0o666], ofItemAtPath: stateFile)
        
        updateStatus()
    }
    
    // Check if Mac is connected to AC Power using IOKit
    private func isACPowerConnected() -> Bool {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return false
        }
        for source in sources {
            if let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] {
                if let state = desc[kIOPSPowerSourceStateKey as String] as? String {
                    return state == (kIOPSACPowerValue as String)
                }
            }
        }
        return false
    }
    
    // Check if daemon is running
    private func isDaemonRunning() -> Bool {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "lid-sleep-daemon.sh"]
        process.standardOutput = pipe
        try? process.run()
        process.waitUntilExit()
        return process.terminationStatus == 0
    }
    
    // Refresh status bar icon and menu
    private func updateStatus() {
        let enabled = isFeatureEnabled()
        let onAC = isACPowerConnected()
        let daemonRunning = isDaemonRunning()
        
        // Configure Icon & Tooltip
        let symbolName: String
        let tooltipText: String
        
        if !enabled {
            symbolName = "moon.zzz.fill"
            tooltipText = "Lid Sleep: Disabled (Normal Sleep)"
        } else if onAC {
            symbolName = "bolt.fill"
            tooltipText = "Lid Sleep: Active (Mac will stay awake on AC)"
        } else {
            symbolName = "battery.100"
            tooltipText = "Lid Sleep: Standby (On Battery, normal sleep)"
        }
        
        if let button = statusItem.button {
            if let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: tooltipText) {
                image.isTemplate = true
                button.image = image
            }
            button.toolTip = tooltipText
        }
        
        // Rebuild Menu
        let menu = NSMenu()
        
        // Header Status
        let statusTitle: String
        if !enabled {
            statusTitle = "Status: Disabled"
        } else if onAC {
            statusTitle = "Status: Active (Awake on AC)"
        } else {
            statusTitle = "Status: Standby (Battery - Will Sleep)"
        }
        
        let headerItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle Item
        let toggleItem = NSMenuItem(
            title: "Keep Awake on AC Power",
            action: #selector(toggleFeature),
            keyEquivalent: ""
        )
        toggleItem.target = self
        toggleItem.state = enabled ? .on : .off
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Info Items
        let powerText = onAC ? "Power Source: AC Adapter Connected" : "Power Source: Battery Power"
        let powerItem = NSMenuItem(title: powerText, action: nil, keyEquivalent: "")
        powerItem.isEnabled = false
        menu.addItem(powerItem)
        
        let daemonText = daemonRunning ? "Background Daemon: Running" : "Background Daemon: Not Running"
        let daemonItem = NSMenuItem(title: daemonText, action: nil, keyEquivalent: "")
        daemonItem.isEnabled = false
        menu.addItem(daemonItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Lid Sleep Manager", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleFeature() {
        let current = isFeatureEnabled()
        setFeatureEnabled(!current)
    }
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
