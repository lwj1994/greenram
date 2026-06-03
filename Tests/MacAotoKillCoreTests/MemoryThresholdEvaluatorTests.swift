import XCTest
@testable import MacAotoKillCore

final class MemoryThresholdEvaluatorTests: XCTestCase {
    func testRamLimitExceeded() {
        let snapshot = makeSnapshot(
            totalPhysicalBytes: 100,
            usedPhysicalBytes: 91,
            swapUsedBytes: 0
        )

        let evaluation = MemoryThresholdEvaluator.evaluate(
            snapshot: snapshot,
            configuration: MemoryThresholdConfiguration(
                ramLimitPercent: 90,
                swapLimitEnabled: true,
                swapLimitBytes: 2_000
            )
        )

        XCTAssertTrue(evaluation.isExceeded)
    }

    func testSwapLimitExceeded() {
        let snapshot = makeSnapshot(
            totalPhysicalBytes: 100,
            usedPhysicalBytes: 50,
            swapUsedBytes: 2_000
        )

        let evaluation = MemoryThresholdEvaluator.evaluate(
            snapshot: snapshot,
            configuration: MemoryThresholdConfiguration(
                ramLimitPercent: 90,
                swapLimitEnabled: true,
                swapLimitBytes: 2_000
            )
        )

        XCTAssertTrue(evaluation.isExceeded)
    }

    func testDisabledSwapLimitDoesNotTrigger() {
        let snapshot = makeSnapshot(
            totalPhysicalBytes: 100,
            usedPhysicalBytes: 50,
            swapUsedBytes: 2_000
        )

        let evaluation = MemoryThresholdEvaluator.evaluate(
            snapshot: snapshot,
            configuration: MemoryThresholdConfiguration(
                ramLimitPercent: 90,
                swapLimitEnabled: false,
                swapLimitBytes: 2_000
            )
        )

        XCTAssertFalse(evaluation.isExceeded)
    }

    func testBelowLimitsStaysNormal() {
        let snapshot = makeSnapshot(
            totalPhysicalBytes: 100,
            usedPhysicalBytes: 70,
            swapUsedBytes: 1_000
        )

        let evaluation = MemoryThresholdEvaluator.evaluate(
            snapshot: snapshot,
            configuration: MemoryThresholdConfiguration(
                ramLimitPercent: 90,
                swapLimitEnabled: true,
                swapLimitBytes: 2_000
            )
        )

        XCTAssertFalse(evaluation.isExceeded)
        XCTAssertTrue(evaluation.reasons.isEmpty)
    }

    private func makeSnapshot(
        totalPhysicalBytes: UInt64,
        usedPhysicalBytes: UInt64,
        swapUsedBytes: UInt64
    ) -> SystemMemorySnapshot {
        SystemMemorySnapshot(
            totalPhysicalBytes: totalPhysicalBytes,
            usedPhysicalBytes: usedPhysicalBytes,
            freePhysicalBytes: totalPhysicalBytes - usedPhysicalBytes,
            compressedBytes: 0,
            swapTotalBytes: 8_000,
            swapUsedBytes: swapUsedBytes,
            swapAvailableBytes: 8_000 - swapUsedBytes
        )
    }
}
