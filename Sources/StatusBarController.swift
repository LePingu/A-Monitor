import Cocoa

@MainActor
class StatusBarController {
    private var statusBarItem: NSStatusItem!
    private var cpuStatusItem: NSStatusItem!
    private var timer: Timer?

    init() {
        setupStatusBarItems()
        startMonitoring()
    }

    deinit {
        MemoryMonitor.shared.stopMonitoring()
        CpuMonitor.shared.stopMonitoring()
    }

    private func setupStatusBarItems() {
        // Memory status item
        statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusBarItem.button {
            button.title = "Mem: Loading..."
            button.action = #selector(statusBarButtonClicked)
        }
        setupMemoryMenu()

        // CPU status item
        cpuStatusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = cpuStatusItem.button {
            button.title = "CPU: Loading..."
            button.action = #selector(cpuStatusBarButtonClicked)
        }
        setupCpuMenu()
    }

    private func startMonitoring() {
        startMemoryMonitoring()
        startCpuMonitoring()
    }

    private func startMemoryMonitoring() {
        MemoryMonitor.shared.setOnMemoryUpdate(callback: { [weak self] memoryInfo in
            guard let strongSelf = self, let button = strongSelf.statusBarItem.button else {
                return
            }
            button.title = "Mem: " + memoryInfo
        })
        MemoryMonitor.shared.startMonitoring()
    }

    private func startCpuMonitoring() {
        CpuMonitor.shared.setOnCpuUpdate(callback: { [weak self] cpuInfo in
            guard let strongSelf = self, let button = strongSelf.cpuStatusItem.button else {
                return
            }
            button.title = "CPU: " + cpuInfo
        })
        CpuMonitor.shared.startMonitoring()
    }

    private func setupMemoryMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Memory Details", action: #selector(showMemoryDetails), keyEquivalent: "M"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Refresh", action: #selector(refreshMemoryInfo), keyEquivalent: "R"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusBarItem.menu = menu
    }

    private func setupCpuMenu() {
        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "CPU Details", action: #selector(showCpuDetails), keyEquivalent: "C"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(
            NSMenuItem(
                title: "Refresh", action: #selector(refreshCpuInfo), keyEquivalent: "U"))
        cpuStatusItem.menu = menu
    }

    @objc private func statusBarButtonClicked() {
        if let button = statusBarItem.button {
            button.performClick(nil)
        }
    }

    @objc private func cpuStatusBarButtonClicked() {
        if let button = cpuStatusItem.button {
            button.performClick(nil)
        }
    }

    @objc private func refreshMemoryInfo() {
        MemoryMonitor.shared.stopMonitoring()
        MemoryMonitor.shared.startMonitoring()
    }

    @objc private func refreshCpuInfo() {
        CpuMonitor.shared.stopMonitoring()
        CpuMonitor.shared.startMonitoring()
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

    @objc private func showCpuDetails() {
        let cpuUsage = CpuMonitor.shared.getCurrentCpuUsage()
        let title = "CPU Usage Details"
        let body = String(format: "Current CPU Usage: %.1f%%", cpuUsage)
        
        NotificationManager.shared.showNotification(title: title, subtitle: nil, body: body)
    }
}
