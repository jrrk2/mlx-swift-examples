import Foundation
// Remove MLX import to avoid Metal initialization

// Dummy GPU snapshot structure that mimics MLX.GPU.Snapshot
struct DummyGPUSnapshot {
    let allocatedMemory: Int
    let peakMemory: Int
    let cacheMemory: Int
    let activeMemory: Int
    
    init(allocated: Int = 0, peak: Int = 0, cache: Int = 0) {
        self.allocatedMemory = allocated
        self.peakMemory = peak
        self.cacheMemory = cache
        self.activeMemory = 0
    }
    
    func delta(_ other: DummyGPUSnapshot) -> DummyGPUSnapshot {
        return DummyGPUSnapshot(
            allocated: other.allocatedMemory - self.allocatedMemory,
            peak: max(other.peakMemory, self.peakMemory),
            cache: other.cacheMemory - self.cacheMemory
        )
    }
}

@Observable
final class DeviceStat: @unchecked Sendable {

    @MainActor
    var gpuUsage = DummyGPUSnapshot()

    private let initialGPUSnapshot = DummyGPUSnapshot()
    private var timer: Timer?
    private var simulatedMemory: Int = 0

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateGPUUsages()
        }
    }

    deinit {
        timer?.invalidate()
    }

    private func updateGPUUsages() {
        // Simulate some memory usage changes for demo purposes
        simulatedMemory += Int.random(in: -100...200)
        simulatedMemory = max(0, simulatedMemory) // Don't go negative
        
        let currentSnapshot = DummyGPUSnapshot(
            allocated: simulatedMemory,
            peak: max(simulatedMemory, initialGPUSnapshot.peakMemory),
            cache: simulatedMemory / 2
        )
        
        let gpuSnapshotDelta = initialGPUSnapshot.delta(currentSnapshot)
        
        DispatchQueue.main.async { [weak self] in
            self?.gpuUsage = gpuSnapshotDelta
        }
    }
}

// Alternative: Even simpler version that just provides static data
@Observable 
final class StaticDeviceStat: @unchecked Sendable {
    
    @MainActor
    var gpuUsage = DummyGPUSnapshot(allocated: 0, peak: 0, cache: 0)
    
    init() {
        // No timer needed - just static values
    }
}

// Usage example - replace your existing DeviceStat with either:
// let deviceStat = DeviceStat()        // Simulated changing values
// let deviceStat = StaticDeviceStat()  // Static zero values


