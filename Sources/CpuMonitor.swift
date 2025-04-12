import Cocoa
import Foundation

// Structure to store CPU usage details by type
struct CPUUsage {
    var user: Double = 0.0
    var system: Double = 0.0
    var idle: Double = 0.0
    var nice: Double = 0.0

    var total: Double {
        return user + system
    }
}

class CpuMonitor: @unchecked Sendable {
    static let shared = CpuMonitor()
    private var timer: Timer?
    private let stateQueue = DispatchQueue(label: "com.cpumonitor.stateQueue")
    private let updateInterval: TimeInterval = 5.0
    private var _onCpuUpdate: ((String) -> Void)?

    // CPU info storage
    private var previousLoadInfo = host_cpu_load_info()
    private var cpuUsageLock = NSLock()

    // For per-core calculations
    private var prevCpuInfo: processor_info_array_t?
    private var numPrevCpuInfo: mach_msg_type_number_t = 0
    private var coreUsages: [Double] = []
    private var numberOfCores: Int = 0

    // Public method to update the callback safely
    func setOnCpuUpdate(callback: @escaping (String) -> Void) {
        stateQueue.sync {
            _onCpuUpdate = callback
        }
    }

    private init() {
        // Determine number of cores
        var size: size_t = MemoryLayout<Int32>.size
        sysctlbyname("hw.logicalcpu", &numberOfCores, &size, nil, 0)

        startMonitoring()
    }

    func startMonitoring() {
        stateQueue.sync {
            timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) {
                [weak self] _ in
                self?.updateCpuInfo()
            }
            timer?.tolerance = 0.1
            RunLoop.current.add(timer!, forMode: .common)
        }
        // Initial update
        updateCpuInfo()
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func getCurrentCpuUsage() -> Double {
        return getSystemCpuUsage().total
    }

    // Get detailed CPU usage information
    func getDetailedCpuUsage() -> CPUUsage {
        return getSystemCpuUsage()
    }

    // Get per-core CPU usage information
    func getPerCoreCpuUsage() -> [Double] {
        var result: [Double] = []
        cpuUsageLock.lock()
        result = coreUsages
        cpuUsageLock.unlock()
        return result
    }

    private func updateCpuInfo() {
        let cpuUsage = getSystemCpuUsage().total
        readPerCoreCpuUsage()

        let formattedUsage = formatCpuUsage(cpuUsage)
        let updateCallback = stateQueue.sync { return _onCpuUpdate }
        DispatchQueue.main.async {
            updateCallback?(formattedUsage)
        }
    }

    // Get system-wide CPU usage - more accurate calculation based on ProcessorKit
    private func getSystemCpuUsage() -> CPUUsage {
        let cpuLoad = hostCPULoadInfo()
        guard let cpuLoad = cpuLoad else {
            return CPUUsage()
        }

        let userDiff = Double(cpuLoad.cpu_ticks.0 - previousLoadInfo.cpu_ticks.0)
        let systemDiff = Double(cpuLoad.cpu_ticks.1 - previousLoadInfo.cpu_ticks.1)
        let idleDiff = Double(cpuLoad.cpu_ticks.2 - previousLoadInfo.cpu_ticks.2)
        let niceDiff = Double(cpuLoad.cpu_ticks.3 - previousLoadInfo.cpu_ticks.3)

        let totalTicks = userDiff + systemDiff + idleDiff + niceDiff

        var usage = CPUUsage()
        if totalTicks > 0 {
            usage.user = userDiff / totalTicks * 100.0
            usage.system = systemDiff / totalTicks * 100.0
            usage.idle = idleDiff / totalTicks * 100.0
            usage.nice = niceDiff / totalTicks * 100.0
        }

        // Store current values for next calculation
        previousLoadInfo = cpuLoad

        return usage
    }

    // Get host CPU load info - helper function
    private func hostCPULoadInfo() -> host_cpu_load_info? {
        let hostCPULoadInfoCount =
            MemoryLayout<host_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        var size = mach_msg_type_number_t(hostCPULoadInfoCount)
        var info = host_cpu_load_info()

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: hostCPULoadInfoCount) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &size)
            }
        }

        if result != KERN_SUCCESS {
            print("Error getting CPU load info: \(result)")
            return nil
        }

        return info
    }

    // Calculate per-core CPU usage - based on stats implementation
    private func readPerCoreCpuUsage() {
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCPUsU: natural_t = 0

        let result = host_processor_info(
            mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUsU, &cpuInfo, &numCpuInfo)

        if result != KERN_SUCCESS {
            print("Error getting per-core CPU info: \(result)")
            return
        }

        defer {
            // Clean up previous CPU info
            if let prevCpuInfo = prevCpuInfo {
                let prevCpuInfoSize = MemoryLayout<integer_t>.stride * Int(numPrevCpuInfo)
                vm_deallocate(
                    mach_task_self_, vm_address_t(bitPattern: prevCpuInfo),
                    vm_size_t(prevCpuInfoSize))
            }

            // Store current as previous for next calculation
            prevCpuInfo = cpuInfo
            numPrevCpuInfo = numCpuInfo

            // Reset for next call
            cpuInfo = nil
            numCpuInfo = 0
        }

        cpuUsageLock.lock()
        var newCoreUsages: [Double] = []

        if let cpuInfo = cpuInfo {
            let cpuInfoArray = UnsafeBufferPointer(start: cpuInfo, count: Int(numCpuInfo))

            for i in 0..<Int(numCPUsU) {
                var inUse: Int32
                var total: Int32

                if let prevCpuInfo = self.prevCpuInfo {
                    // Calculate difference between current and previous measurement
                    let userDiff =
                    cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)]
                    - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)]
                    let systemDiff =
                    cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)]
                    - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)]
                    let niceDiff =
                    cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_NICE)]
                    - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_NICE)]
                    let idleDiff =
                    cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)]
                    - prevCpuInfo[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)]

                    inUse = userDiff + systemDiff + niceDiff
                    total = inUse + idleDiff
                } else {
                    // First measurement - use absolute values
                    let user = cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_USER)]
                    let system = cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_SYSTEM)]
                    let nice = cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_NICE)]
                    let idle = cpuInfoArray[Int(CPU_STATE_MAX * Int32(i) + CPU_STATE_IDLE)]

                    inUse = user + system + nice
                    total = inUse + idle
                }

                // Calculate usage percentage for this core
                if total > 0 {
                    let usage = Double(inUse) / Double(total) * 100.0
                    newCoreUsages.append(usage)
                } else {
                    newCoreUsages.append(0.0)
                }
            }
        }

        self.coreUsages = newCoreUsages
        cpuUsageLock.unlock()
    }

    private func formatCpuUsage(_ usage: Double) -> String {
        return String(format: "%.1f%%", usage)
    }
}
