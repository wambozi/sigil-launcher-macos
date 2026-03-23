import Foundation

public struct ModelInfo: Codable, Identifiable {
    public let id: String
    public let name: String
    public let description: String
    public let sizeGB: Double
    public let minRAMGB: Double
    public let quantization: String
    public let parameters: String
    public let downloadURL: String
    public let filename: String
}

public enum ModelCatalog {
    public static let models: [ModelInfo] = [
        ModelInfo(
            id: "qwen2.5-1.5b-q4",
            name: "Qwen 2.5 1.5B",
            description: "Fast, basic suggestions. Best for constrained hardware.",
            sizeGB: 1.0, minRAMGB: 3.0, quantization: "Q4_K_M",
            parameters: "1.5B",
            downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
            filename: "qwen2.5-1.5b-q4_k_m.gguf"
        ),
        ModelInfo(
            id: "phi3-mini-3.8b-q4",
            name: "Phi-3 Mini 3.8B",
            description: "Good balance of speed and quality.",
            sizeGB: 2.5, minRAMGB: 5.0, quantization: "Q4_K_M",
            parameters: "3.8B",
            downloadURL: "https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf",
            filename: "phi3-mini-3.8b-q4_k_m.gguf"
        ),
        ModelInfo(
            id: "llama3.1-8b-q4",
            name: "LLaMA 3.1 8B",
            description: "Best quality. Needs 8GB+ VM RAM.",
            sizeGB: 4.5, minRAMGB: 8.0, quantization: "Q4_K_M",
            parameters: "8B",
            downloadURL: "https://huggingface.co/lmstudio-community/Meta-Llama-3.1-8B-Instruct-GGUF/resolve/main/Meta-Llama-3.1-8B-Instruct-Q4_K_M.gguf",
            filename: "llama3.1-8b-q4_k_m.gguf"
        ),
    ]

    /// Returns models that can run within the given VM RAM allocation.
    /// Reserves 2GB for OS + daemon overhead.
    public static func availableModels(forVMRAMGB vmRAM: Int) -> [ModelInfo] {
        let availableForModel = Double(vmRAM) - 2.0
        return models.filter { $0.minRAMGB <= Double(vmRAM) && $0.sizeGB <= availableForModel }
    }
}
