import XCTest
@testable import SigilLauncherLib

final class ModelCatalogTests: XCTestCase {

    // MARK: - Catalog Contents

    func testCatalogHasThreeModels() {
        XCTAssertEqual(ModelCatalog.models.count, 3)
    }

    func testCatalogModelIds() {
        let ids = ModelCatalog.models.map { $0.id }
        XCTAssertTrue(ids.contains("qwen2.5-1.5b-q4"))
        XCTAssertTrue(ids.contains("phi3-mini-3.8b-q4"))
        XCTAssertTrue(ids.contains("llama3.1-8b-q4"))
    }

    func testAllModelsHaveDownloadURLs() {
        for model in ModelCatalog.models {
            XCTAssertTrue(model.downloadURL.hasPrefix("https://"), "Model \(model.id) has invalid download URL")
            XCTAssertFalse(model.filename.isEmpty, "Model \(model.id) has empty filename")
        }
    }

    // MARK: - Available Models Filtering

    func testAvailableModelsFor4GBReturnsOnlyQwen() {
        let available = ModelCatalog.availableModels(forVMRAMGB: 4)

        XCTAssertEqual(available.count, 1)
        XCTAssertEqual(available.first?.id, "qwen2.5-1.5b-q4")
    }

    func testAvailableModelsFor8GBReturnsAll() {
        let available = ModelCatalog.availableModels(forVMRAMGB: 8)

        XCTAssertEqual(available.count, 3)
        let ids = available.map { $0.id }
        XCTAssertTrue(ids.contains("qwen2.5-1.5b-q4"))
        XCTAssertTrue(ids.contains("phi3-mini-3.8b-q4"))
        XCTAssertTrue(ids.contains("llama3.1-8b-q4"))
    }

    func testAvailableModelsFor2GBReturnsEmpty() {
        let available = ModelCatalog.availableModels(forVMRAMGB: 2)

        XCTAssertTrue(available.isEmpty)
    }

    func testAvailableModelsFor6GBReturnsTwoSmallest() {
        let available = ModelCatalog.availableModels(forVMRAMGB: 6)

        // 6GB VM: 4GB available for model after 2GB OS overhead
        // Qwen: needs 3GB min RAM, 1.0GB size <= 4GB available -> yes
        // Phi-3: needs 5GB min RAM, 2.5GB size <= 4GB available -> yes (5 <= 6 for minRAM, 2.5 <= 4 for size)
        // LLaMA: needs 8GB min RAM -> no (8 > 6)
        XCTAssertEqual(available.count, 2)
        let ids = available.map { $0.id }
        XCTAssertTrue(ids.contains("qwen2.5-1.5b-q4"))
        XCTAssertTrue(ids.contains("phi3-mini-3.8b-q4"))
        XCTAssertFalse(ids.contains("llama3.1-8b-q4"))
    }

    func testAvailableModelsFor0GBReturnsEmpty() {
        let available = ModelCatalog.availableModels(forVMRAMGB: 0)
        XCTAssertTrue(available.isEmpty)
    }
}
