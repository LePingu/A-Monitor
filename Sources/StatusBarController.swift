import Cocoa

@MainActor
class StatusBarController {
    private var statusBarItem: NSStatusItem!
    private var timer: Timer?

    init() {
        setupStatusBarItem()
        startMemoryMonitoring()
    }

    deinit {
        MemoryMonitor.shared.stopMonitoring()
    }

    private func setupStatusBarItem() {
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.title = "Loading..."
            button.action = #selector(statusBarButtonClicked)
        }
        setupMenu()
    }

    private func startMemoryMonitoring() {
        MemoryMonitor.shared.setOnMemoryUpdate(callback: { [weak self] memoryInfo in
            guard let strongSelf = self, let button = strongSelf.statusBarItem.button else {
                return
            }
            button.title = memoryInfo
        })
        MemoryMonitor.shared.startMonitoring()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Memory Details", action: #selector(showMemoryDetails), keyEquivalent: "M"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Refresh Now", action: #selector(refreshMemoryInfo), keyEquivalent: "R"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem.menu = menu
    }

    @objc private func statusBarButtonClicked() {
        if let button = statusBarItem.button {
            button.performClick(nil)
        }
    }

    @objc private func refreshMemoryInfo() {
        // Force a refresh of memory info
        MemoryMonitor.shared.stopMonitoring()
        MemoryMonitor.shared.startMonitoring()
    }

    @objc private func showMemoryDetails() {
        let memoryUsage = MemoryMonitor.shared.getCurrentMemoryUsage()
        let title = "Memory Usage Details"
        let usedGB = Double(memoryUsage.used) / 1_073_741_824
        let totalGB = Double(memoryUsage.total) / 1_073_741_824
        let percentUsed = (Double(memoryUsage.used) / Double(memoryUsage.total)) * 100

        let body = String(
            format: """
                Used: %.2f GB
                Total: %.2f GB
                Usage: %.1f%%
                """, usedGB, totalGB, percentUsed)

        NotificationManager.shared.showNotification(title: title, subtitle: nil, body: body)
    }
}
