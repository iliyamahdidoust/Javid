import Foundation

class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    private init() {}
    
    func measureTime(_ label: String, block: () -> Void) {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let end = CFAbsoluteTimeGetCurrent()
        print("\(label): \(String(format: "%.4f", end - start)) seconds")
    }
    
    func measureAsyncTime(_ label: String, block: () async -> Void) async {
        let start = CFAbsoluteTimeGetCurrent()
        await block()
        let end = CFAbsoluteTimeGetCurrent()
        print("\(label): \(String(format: "%.4f", end - start)) seconds")
    }
}
