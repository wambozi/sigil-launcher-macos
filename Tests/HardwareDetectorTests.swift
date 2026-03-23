import XCTest
@testable import SigilLauncherLib

final class HardwareDetectorTests: XCTestCase {

    // MARK: - Recommend

    func testRecommendWith16GB8Cores() {
        let hw = HardwareInfo(totalRAMGB: 16, cpuCores: 8, cpuArch: "arm64", diskAvailableGB: 100, gpuName: nil)
        let rec = HardwareDetector.recommend(for: hw)

        XCTAssertEqual(rec.memoryGB, 8)   // 16/2 = 8, clamped to [4, 12]
        XCTAssertEqual(rec.cpus, 4)       // 8/2 = 4, max(4, 2) = 4
        XCTAssertEqual(rec.diskGB, 20)
    }

    func testRecommendWith8GB4Cores() {
        let hw = HardwareInfo(totalRAMGB: 8, cpuCores: 4, cpuArch: "arm64", diskAvailableGB: 50, gpuName: nil)
        let rec = HardwareDetector.recommend(for: hw)

        XCTAssertEqual(rec.memoryGB, 4)   // 8/2 = 4, clamped to [4, 12]
        XCTAssertEqual(rec.cpus, 2)       // 4/2 = 2, max(2, 2) = 2
        XCTAssertEqual(rec.diskGB, 20)
    }

    func testRecommendClampsToMin4GB() {
        // 6GB system -> 6/2 = 3, but min is 4
        let hw = HardwareInfo(totalRAMGB: 6, cpuCores: 2, cpuArch: "x86_64", diskAvailableGB: 30, gpuName: nil)
        let rec = HardwareDetector.recommend(for: hw)

        XCTAssertEqual(rec.memoryGB, 4)
        XCTAssertEqual(rec.cpus, 2)  // max(2/2, 2) = max(1, 2) = 2
    }

    func testRecommendClampsToMax12GB() {
        // 32GB system -> 32/2 = 16, but max is 12
        let hw = HardwareInfo(totalRAMGB: 32, cpuCores: 16, cpuArch: "arm64", diskAvailableGB: 200, gpuName: "Apple M1 Max")
        let rec = HardwareDetector.recommend(for: hw)

        XCTAssertEqual(rec.memoryGB, 12)
        XCTAssertEqual(rec.cpus, 8)
    }

    func testRecommendWith64GB32Cores() {
        let hw = HardwareInfo(totalRAMGB: 64, cpuCores: 32, cpuArch: "arm64", diskAvailableGB: 500, gpuName: "Apple M2 Ultra")
        let rec = HardwareDetector.recommend(for: hw)

        XCTAssertEqual(rec.memoryGB, 12)  // clamped at 12
        XCTAssertEqual(rec.cpus, 16)      // 32/2
    }

    // MARK: - Minimum Requirements

    func testMeetsMinimumRequirementsFailsBelow8GB() {
        let hw = HardwareInfo(totalRAMGB: 4, cpuCores: 4, cpuArch: "arm64", diskAvailableGB: 50, gpuName: nil)
        let (meets, message) = HardwareDetector.meetsMinimumRequirements(hw)

        XCTAssertFalse(meets)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("8GB"))
    }

    func testMeetsMinimumRequirementsFailsBelow10GBDisk() {
        let hw = HardwareInfo(totalRAMGB: 16, cpuCores: 8, cpuArch: "arm64", diskAvailableGB: 5, gpuName: nil)
        let (meets, message) = HardwareDetector.meetsMinimumRequirements(hw)

        XCTAssertFalse(meets)
        XCTAssertNotNil(message)
        XCTAssertTrue(message!.contains("10GB"))
    }

    func testMeetsMinimumRequirementsPassesWith8GBAndEnoughDisk() {
        let hw = HardwareInfo(totalRAMGB: 8, cpuCores: 4, cpuArch: "arm64", diskAvailableGB: 50, gpuName: nil)
        let (meets, message) = HardwareDetector.meetsMinimumRequirements(hw)

        XCTAssertTrue(meets)
        XCTAssertNil(message)
    }

    func testMeetsMinimumRequirementsPassesWithPlenty() {
        let hw = HardwareInfo(totalRAMGB: 32, cpuCores: 16, cpuArch: "arm64", diskAvailableGB: 500, gpuName: "Apple M2 Max")
        let (meets, message) = HardwareDetector.meetsMinimumRequirements(hw)

        XCTAssertTrue(meets)
        XCTAssertNil(message)
    }

    func testMeetsMinimumRequirementsRAMCheckTakesPriority() {
        // Both RAM and disk are below minimum — RAM check comes first
        let hw = HardwareInfo(totalRAMGB: 4, cpuCores: 2, cpuArch: "x86_64", diskAvailableGB: 5, gpuName: nil)
        let (meets, message) = HardwareDetector.meetsMinimumRequirements(hw)

        XCTAssertFalse(meets)
        XCTAssertTrue(message!.contains("RAM"))
    }
}
