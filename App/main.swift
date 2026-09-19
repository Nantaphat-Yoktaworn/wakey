import Cocoa
import IOKit.ps

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var updateTimer: Timer?
    private var powerRunLoopSource: CFRunLoopSource?
    
    private let stateDir = "/Library/Application Support/LidSleepManager"
    private let stateFile = "/Library/Application Support/LidSleepManager/enabled"
    private let daemonPlistPath = "/Library/LaunchDaemons/com.lidsleepmanager.daemon.plist"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        // Initial setup
        updateStatus()
        
        // Setup immediate power-change listener using IOKit
        setupPowerNotification()
        
        // Fallback periodic timer every 3 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.updateStatus()
        }
        
        // Prompt user on first launch if helper daemon is missing
        checkAndPromptDaemonInstallation()
    }
    
    // Register for real-time power source changes
    private func setupPowerNotification() {
        let context = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        if let source = IOPSNotificationCreateRunLoopSource({ ctx in
            guard let ctx = ctx else { return }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(ctx).takeUnretainedValue()
            DispatchQueue.main.async {
                delegate.updateStatus()
            }
        }, context)?.takeRetainedValue() {
            powerRunLoopSource = source
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .defaultMode)
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
    
    // Check if daemon plist is present
    private func isDaemonInstalled() -> Bool {
        return FileManager.default.fileExists(atPath: daemonPlistPath)
    }
    
    // Prompt to install helper on launch if not installed
    private func checkAndPromptDaemonInstallation() {
        if !isDaemonInstalled() {
            DispatchQueue.main.async { [weak self] in
                let alert = NSAlert()
                alert.messageText = "Install Wakey Helper Service"
                alert.informativeText = "Wakey requires a lightweight background helper service to keep your Mac awake when the lid is closed on AC power.\n\nWould you like to install it now?"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Install")
                alert.addButton(withTitle: "Later")
                
                if alert.runModal() == .alertFirstButtonReturn {
                    self?.installDaemon()
                }
            }
        }
    }
    
    // Create the minimal MacBook icon for status menu (matching app logo)
    private func createStatusIcon(halfOpen: Bool, active: Bool, warning: Bool) -> NSImage {
        let size = NSSize(width: 19, height: 16)
        let image = NSImage(size: size)
        image.lockFocus()
        
        NSColor.black.setFill()
        NSColor.black.setStroke()
        
        // Laptop Base
        let basePath = NSBezierPath(roundedRect: NSRect(x: 1, y: 2, width: 17, height: 2.4), xRadius: 1.0, yRadius: 1.0)
        basePath.fill()
        
        // Subtle thumb notch
        NSColor.clear.setFill()
        let notch = NSRect(x: 8, y: 3.4, width: 3, height: 1)
        notch.fill()
        NSColor.black.setFill()
        
        if warning {
            // Closed lid with a warning dot
            let lidPath = NSBezierPath(roundedRect: NSRect(x: 1, y: 4.4, width: 17, height: 2.0), xRadius: 0.8, yRadius: 0.8)
            lidPath.fill()
            
            // Warning dot
            let dot = NSBezierPath(ovalIn: NSRect(x: 14.5, y: 8.5, width: 3.5, height: 3.5))
            dot.fill()
        } else if halfOpen {
            // Angled screen / lid
            let lidPath = NSBezierPath()
            lidPath.lineWidth = 2.0
            lidPath.lineCapStyle = .round
            lidPath.move(to: NSPoint(x: 2.5, y: 4.5))
            lidPath.line(to: NSPoint(x: 13.5, y: 14.5))
            lidPath.stroke()
            
            if active {
                // Active screen glow beam
                let glowPath = NSBezierPath()
                glowPath.lineWidth = 1.2
                glowPath.lineCapStyle = .round
                glowPath.move(to: NSPoint(x: 6.0, y: 5.5))
                glowPath.line(to: NSPoint(x: 10.5, y: 9.5))
                glowPath.stroke()
                
                // Small power indicator dot
                let dot = NSBezierPath(ovalIn: NSRect(x: 15.0, y: 11.0, width: 2.8, height: 2.8))
                dot.fill()
            }
        } else {
            // Flat closed lid (Disabled state)
            let lidPath = NSBezierPath(roundedRect: NSRect(x: 1, y: 4.4, width: 17, height: 2.0), xRadius: 0.8, yRadius: 0.8)
            lidPath.fill()
        }
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    // Refresh status bar icon and menu
    func updateStatus() {
        let enabled = isFeatureEnabled()
        let onAC = isACPowerConnected()
        let daemonRunning = isDaemonRunning()
        let daemonInstalled = isDaemonInstalled()
        
        let isAwakeActive = enabled && onAC && daemonRunning
        let hasWarning = !daemonInstalled || !daemonRunning
        
        // Configure Icon & Tooltip
        let tooltipText: String
        if hasWarning {
            tooltipText = "Wakey: Helper Service Not Running"
        } else if !enabled {
            tooltipText = "Wakey: Disabled (Normal Sleep)"
        } else if onAC {
            tooltipText = "Wakey: Active (Awake on AC with lid closed)"
        } else {
            tooltipText = "Wakey: Standby (On Battery - will sleep on lid close)"
        }
        
        if let button = statusItem.button {
            button.image = createStatusIcon(
                halfOpen: enabled && daemonRunning,
                active: isAwakeActive,
                warning: hasWarning
            )
            button.toolTip = tooltipText
        }
        
        // Rebuild Menu
        let menu = NSMenu()
        
        // Header Status
        let statusTitle: String
        if hasWarning {
            statusTitle = "Wakey: Helper Service Stopped"
        } else if !enabled {
            statusTitle = "Wakey: Disabled"
        } else if isAwakeActive {
            statusTitle = "Wakey: Active (Awake on AC)"
        } else {
            statusTitle = "Wakey: Standby (Battery - Will Sleep)"
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
        let powerText = onAC ? "Power: AC Adapter Connected" : "Power: On Battery"
        let powerItem = NSMenuItem(title: powerText, action: nil, keyEquivalent: "")
        powerItem.isEnabled = false
        menu.addItem(powerItem)
        
        let daemonText = daemonRunning ? "Helper Service: Running" : "Helper Service: Not Running"
        let daemonItem = NSMenuItem(title: daemonText, action: nil, keyEquivalent: "")
        daemonItem.isEnabled = false
        menu.addItem(daemonItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Helper Service Actions
        if hasWarning {
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
                action: #selector(confirmUninstallDaemon),
                keyEquivalent: ""
            )
            uninstallItem.target = self
            menu.addItem(uninstallItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Wakey", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    @objc private func toggleFeature() {
        let current = isFeatureEnabled()
        setFeatureEnabled(!current)
    }
    
    // Install helper daemon with admin privileges
    @objc private func installDaemon() {
        guard let resourcePath = Bundle.main.resourcePath else {
            showAlert(title: "Error", message: "Resource directory not found in application bundle.")
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
    
    // Explicit confirmation dialog before uninstalling
    @objc private func confirmUninstallDaemon() {
        let alert = NSAlert()
        alert.messageText = "Uninstall Wakey Helper Service?"
        alert.informativeText = "This will remove the background helper service and restore default macOS sleep behavior.\n\nYour Mac will sleep normally whenever the lid is closed.\n\nAre you sure you want to proceed?"
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Uninstall")
        alert.addButton(withTitle: "Cancel")
        
        // Show confirmation dialog
        if alert.runModal() == .alertFirstButtonReturn {
            executeUninstallDaemon()
        }
    }
    
    private func executeUninstallDaemon() {
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
    
    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// Entry Point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
