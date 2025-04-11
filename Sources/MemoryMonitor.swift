import Cocoa
import Darwin
import Foundation

class MemoryMonitor: @unchecked Sendable {
    static let shared = MemoryMonitor()
    private var timer: Timer?
    private let stateQueue = DispatchQueue(label: "com.memorymonitor.stateQueue")
    private let updateInterval: TimeInterval = 5.0  // Set the update interval in seconds
    private var _onMemoryUpdate: ((String) -> Void)?

    // Public method to update the callback safely
    func setOnMemoryUpdate(callback: @escaping (String) -> Void) {
        stateQueue.sync {
            _onMemoryUpdate = callback
        }
    }

    private init() {
        startMonitoring()
    }

    func startMonitoring() {
        stateQueue.sync {
            timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) {
                [weak self] _ in
                self?.updateMemoryInfo()
            }
            timer?.tolerance = 0.1
            RunLoop.current.add(timer!, forMode: .common)
        }
        // Initial update
        updateMemoryInfo()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func getCurrentMemoryUsage() -> (used: UInt64, total: UInt64) {
        return getMemoryUsage()
    }

    private func updateMemoryInfo() {
        let memoryUsage = getMemoryUsage()
        let formattedUsage = formatMemoryUsage(memoryUsage)
        let updateCallback = stateQueue.sync { return _onMemoryUpdate }
        DispatchQueue.main.async {
            updateCallback?(formattedUsage)
        }
    }

    private func getMemoryUsage() -> (used: UInt64, total: UInt64) {
        var stats = host_basic_info()
        var count = UInt32(MemoryLayout<host_basic_info_data_t>.size / MemoryLayout<integer_t>.size)

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_info(mach_host_self(), HOST_BASIC_INFO, $0, &count)
            }
        }

        if kerr != KERN_SUCCESS {
            return (0, 0)
        }

        // Get physical memory in use via vm statistics
        let pageSize = vm_size_t(getpagesize())

        var vmStats = vm_statistics64()
        var vmCount = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let vmPtr = withUnsafeMutablePointer(to: &vmStats) { ptr -> UnsafeMutableRawPointer in
            UnsafeMutableRawPointer(ptr)
        }

        if host_statistics64(
            mach_host_self(), HOST_VM_INFO64, vmPtr.assumingMemoryBound(to: integer_t.self),
            &vmCount) != KERN_SUCCESS
        {
            return (0, stats.max_mem)
        }

        let totalMemory = stats.max_mem

        // Fixed calculation to avoid arithmetic overflow
        let activeMemory = UInt64(vmStats.active_count) * UInt64(pageSize)
        let wiredMemory = UInt64(vmStats.wire_count) * UInt64(pageSize)
        let speculativeMemory = UInt64(vmStats.speculative_count) * UInt64(pageSize)
        let inactiveMemory = UInt64(vmStats.inactive_count) * UInt64(pageSize)
        let compressedMemory = UInt64(vmStats.compressor_page_count) * UInt64(pageSize)
        let purgeableMemory = UInt64(vmStats.purgeable_count) * UInt64(pageSize)
        let externalMemory = UInt64(vmStats.external_page_count) * UInt64(pageSize)
        let used =
            activeMemory + wiredMemory + speculativeMemory + inactiveMemory + compressedMemory
            - purgeableMemory - externalMemory

        return (used, totalMemory)
    }

    private func formatMemoryUsage(_ usage: (used: UInt64, total: UInt64)) -> String {
        let usedGB = Double(usage.used) / 1_073_741_824  // Convert to GB
        let totalGB = Double(usage.total) / 1_073_741_824  // Convert to GB
        let percentUsed = (Double(usage.used) / Double(usage.total)) * 100

        return String(format: "%.1f/%.1fGB (%.0f%%)", usedGB, totalGB, percentUsed)
    }
}
