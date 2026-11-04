import Darwin
import XCTest
@testable import MacAotoKillCore

final class SystemMemoryLeakDetectorTests: XCTestCase {
    private let gb: UInt64 = 1024 * 1024 * 1024
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let signpostReaderPath = "/System/Library/PrivateFrameworks/PowerlogCore.framework/Versions/A/XPCServices/PerfPowerServicesSignpostReader.xpc/Contents/MacOS/PerfPowerServicesSignpostReader"

    private func summary(_ processes: [(ProcessTreeEntry, UInt64)], at minutes: Double) -> SystemProcessSummary {
        SystemProcessSummary(
            processes: processes.map { SystemProcessUsage(entry: $0.0, memoryBytes: $0.1) },
            capturedAt: start.addingTimeInterval(minutes * 60)
        )
    }

    private func entry(_ pid: pid_t, _ path: String, userID: uid_t = 0) -> ProcessTreeEntry {
        ProcessTreeEntry(pid: pid, parentPID: 1, memoryBytes: 0, executablePath: path, startTime: 100, userID: userID)
    }

    func testGrowthWithinWindowIsSuspected() {
        let detector = SystemMemoryLeakDetector()
        let mds = entry(200, "/usr/libexec/mds")
        detector.observe(summary([(mds, 2 * gb)], at: 0))
        detector.observe(summary([(mds, 3 * gb)], at: 20))
        let current = summary([(mds, 5 * gb)], at: 40)
        detector.observe(current)

        let suspects = detector.suspects(in: current)
        XCTAssertEqual(suspects.map(\.process.pid), [200])
        XCTAssertEqual(suspects.first?.growthBytes, 3 * gb)
        XCTAssertEqual(suspects.first?.isAutoTerminable, true)
    }

    func testStableLargeProcessIsNotSuspected() {
        let detector = SystemMemoryLeakDetector()
        let qemu = entry(300, "/opt/homebrew/bin/qemu-system-aarch64", userID: getuid())
        for minute in stride(from: 0.0, through: 50, by: 10) {
            detector.observe(summary([(qemu, 8 * gb)], at: minute))
        }

        XCTAssertTrue(detector.suspects(in: summary([(qemu, 8 * gb)], at: 50)).isEmpty)
    }

    func testGrowthOlderThanWindowIsForgotten() {
        let detector = SystemMemoryLeakDetector()
        let mds = entry(200, "/usr/libexec/mds")
        detector.observe(summary([(mds, 1 * gb)], at: 0))
        detector.observe(summary([(mds, 5 * gb)], at: 30))
        let current = summary([(mds, 5 * gb)], at: 90)
        detector.observe(current)

        XCTAssertTrue(detector.suspects(in: current).isEmpty)
    }

    func testKnownLeakyServiceNeedsNoHistory() {
        let detector = SystemMemoryLeakDetector()
        let reader = entry(10, signpostReaderPath)
        let current = summary([(reader, 55 * gb)], at: 0)
        detector.observe(current)

        XCTAssertEqual(detector.suspects(in: current).map(\.process.pid), [10])
        XCTAssertTrue(detector.suspects(in: summary([(reader, 3 * gb)], at: 0)).isEmpty)
    }

    func testUserInstalledProcessIsFlaggedButNotAutoTerminable() {
        let detector = SystemMemoryLeakDetector()
        let java = entry(400, "/Library/Java/JavaVirtualMachines/jdk-21.jdk/Contents/Home/bin/java", userID: getuid())
        detector.observe(summary([(java, 1 * gb)], at: 0))
        let current = summary([(java, 6 * gb)], at: 30)
        detector.observe(current)

        let suspects = detector.suspects(in: current)
        XCTAssertEqual(suspects.map(\.process.pid), [400])
        XCTAssertEqual(suspects.first?.isAutoTerminable, false)
    }

    func testProtectedProcessIsNeverSuspected() {
        let detector = SystemMemoryLeakDetector()
        let windowServer = entry(435, "/System/Library/PrivateFrameworks/SkyLight.framework/Resources/WindowServer")
        detector.observe(summary([(windowServer, 1 * gb)], at: 0))
        let current = summary([(windowServer, 9 * gb)], at: 30)
        detector.observe(current)

        XCTAssertTrue(detector.suspects(in: current).isEmpty)
    }

    func testEachProcessIsHandledOnce() {
        let detector = SystemMemoryLeakDetector()
        let reader = entry(10, signpostReaderPath)
        let current = summary([(reader, 55 * gb)], at: 0)
        detector.observe(current)

        let suspects = detector.unhandledSuspects(in: current)
        XCTAssertEqual(suspects.count, 1)
        detector.markHandled(suspects[0])
        XCTAssertTrue(detector.unhandledSuspects(in: current).isEmpty)

        let restarted = ProcessTreeEntry(pid: 10, parentPID: 1, memoryBytes: 0, executablePath: signpostReaderPath, startTime: 200, userID: 0)
        let afterRestart = summary([(restarted, 55 * gb)], at: 10)
        detector.observe(afterRestart)
        XCTAssertEqual(detector.unhandledSuspects(in: afterRestart).count, 1)
    }
}
