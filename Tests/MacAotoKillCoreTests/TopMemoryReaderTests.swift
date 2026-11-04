import XCTest
@testable import MacAotoKillCore

final class TopMemoryReaderTests: XCTestCase {
    func testParseMemoryUnits() {
        XCTAssertEqual(TopMemoryReader.parseMemory("12B"), 12)
        XCTAssertEqual(TopMemoryReader.parseMemory("900K"), 900 * 1024)
        XCTAssertEqual(TopMemoryReader.parseMemory("512M"), 512 * 1024 * 1024)
        XCTAssertEqual(TopMemoryReader.parseMemory("55G"), 55 * 1024 * 1024 * 1024)
        XCTAssertEqual(TopMemoryReader.parseMemory("28M+"), 28 * 1024 * 1024)
        XCTAssertEqual(TopMemoryReader.parseMemory("1.5G-"), 1536 * 1024 * 1024)
        XCTAssertNil(TopMemoryReader.parseMemory("MEM"))
        XCTAssertNil(TopMemoryReader.parseMemory(""))
    }

    func testParseTopOutputReadsProcessRowsOnly() {
        let output = """
        Processes: 812 total, 3 running, 809 sleeping, 4310 threads
        PhysMem: 15G used (2950M wired, 5120M compressor), 210M unused.

        PID    MEM
        68469  55G
        1      28M+
        """

        XCTAssertEqual(
            TopMemoryReader.parseTopOutput(output),
            [68469: 55 * 1024 * 1024 * 1024, 1: 28 * 1024 * 1024]
        )
    }
}
