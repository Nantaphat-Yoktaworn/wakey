import Cocoa
import IOKit.ps

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var updateTimer: Timer?
    
    private let stateDir = "/Library/Application Support/LidSleepManager"
    private let stateFile = "/Library/Application Support/LidSleepManager/enabled"
    private let daemonPlistPath = "/Library/LaunchDaemons/com.lidsleepmanager.daemon.plist"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item with variable length
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Initial setup
        updateStatus()
        
        // Check if daemon is installed; if not, prompt user
        checkAndPromptDaemonInstallation()
        
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
    
    // Check if plist is installed
    private func isDaemonInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: daemonPlistPath)
    }
    
    // Prompt to install daemon on first launch
    private func checkAndPromptDaemonInstallation() {
        if !isDaemonInstalled() {
            DispatchQueue.main.async { [weak self] in
                let alert = NSAlert()
                alert.messageText = "Install Background Service"
                alert.informativeText = "Lid Sleep Manager requires a lightweight background helper service to manage sleep settings when the lid is closed.\n\nWould you like to install it now?"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Install")
                alert.addButton(withTitle: "Later")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    self?.installDaemon()
                }
            }
        }
    }
    
    // Install daemon with admin privileges
    @objc private func installDaemon() {
        guard let resourcePath = Bundle.main.resourcePath else {
            showAlert(title: "Error", message: "Resource directory not found inside application bundle.")
            return
        }
        
        let daemonScript = "\(resourcePath)/lid-sleep-daemon.sh"
        let daemonPlist = "\(resourcePath)/com.lidsleepmanager.daemon.plist"
        
        guard FileManager.default.fileExists(atPath: daemonScript),
              FileManager.default.fileExists(atPath: daemonPlist) else {
            showAlert(title: "Error", message: "Daemon resources missing in app bundle.")
            return
        }
        
        let command = """
        mkdir -p '/usr/local/bin' && \
        mkdir -p '/Library/Application Support/LidSleepManager' && \
        chmod 777 '/Library/Application Support/LidSleepManager' && \
        if [ ! -f '/Library/Application Support/LidSleepManager/enabled' ]; then echo '1' > '/Library/Application Support/LidSleepManager/enabled'; fi && \
        chmod 666 '/Library/Application Support/LidSleepManager/enabled' && \
        cp '\(daemonScript)' /usr/local/bin/lid-sleep-daemon.sh && \
        chmod +x /usr/local/bin/lid-sleep-daemon.sh && \
        cp '\(daemonPlist)' /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist && \
        chown root:wheel /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist && \
        chmod 644 /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist && \
        launchctl unload -w /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist 2>/dev/null || true && \
        launchctl load -w /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist
        """
        
        let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: appleScript) {
            script.executeAndReturnError(&error)
            if let error = error {
                let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                showAlert(title: "Installation Failed", message: errorMsg)
            } else {
                updateStatus()
            }
        }
    }
    
    // Uninstall daemon with admin privileges
    @objc private func uninstallDaemon() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Background Service"
        alert.informativeText = "Are you sure you want to uninstall the background service? Default macOS sleep behavior will be restored."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        
        let command = """
        launchctl unload -w /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist 2>/dev/null || true && \
        rm -f /Library/LaunchDaemons/com.lidsleepmanager.daemon.plist /usr/local/bin/lid-sleep-daemon.sh && \
        rm -rf '/Library/Application Support/LidSleepManager' && \
        /usr/bin/pmset -a disablesleep 0
        """
        
        let escapedCommand = command.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escapedCommand)\" with administrator privileges"
        
        var error: NSDictionary?
        if let script = NSAppleScript(source: appleScript) {
            script.executeAndReturnError(&error)
            if let error = error {
                let errorMsg = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                showAlert(title: "Uninstallation Failed", message: errorMsg)
            } else {
                updateStatus()
            }
        }
    }
    
    private func showAlert(title: String, message: String) {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = title
            alert.informativeText = message
            alert.runModal()
        }
    }
    
    // Refresh status bar icon and menu
    private func updateStatus() {
        let enabled = isFeatureEnabled()
        let onAC = isACPowerConnected()
        let daemonRunning = isDaemonRunning()
        let daemonInstalled = isDaemonInstalled()
        
        // Configure Icon & Tooltip
        let symbolName: String
        let tooltipText: String
        
        if !daemonInstalled || !daemonRunning {
            symbolName = "exclamationmark.triangle.fill"
            tooltipText = "Lid Sleep: Service Not Running"
        } else if !enabled {
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
        if !daemonInstalled || !daemonRunning {
            statusTitle = "Status: Helper Service Not Running"
        } else if !enabled {
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
        toggleItem.state = (enabled && daemonRunning) ? .on : .off
        toggleItem.isEnabled = daemonRunning
        menu.addItem(toggleItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Info Items
        let powerText = onAC ? "Power Source: AC Adapter Connected" : "Power Source: Battery Power"
        let powerItem = NSMenuItem(title: powerText, action: nil, keyEquivalent: "")
        powerItem.isEnabled = false
        menu.addItem(powerItem)
        
        let daemonText = daemonRunning ? "Background Service: Running" : "Background Service: Stopped"
        let daemonItem = NSMenuItem(title: daemonText, action: nil, keyEquivalent: "")
        daemonItem.isEnabled = false
        menu.addItem(daemonItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Helper Service Actions
        if !daemonRunning || !daemonInstalled {
            let installItem = NSMenuItem(
                title: "Install / Start Helper Service...",
                action: #selector(installDaemon),
                keyEquivalent: ""
            )
            installItem.target = self
            menu.addItem(installItem)
        } else {
            let uninstallItem = NSMenuItem(
                title: "Uninstall Helper Service...",
                action: #selector(uninstallDaemon),
                keyEquivalent: ""
            )
            uninstallItem.target = self
            menu.addItem(uninstallItem)
        }
        
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
