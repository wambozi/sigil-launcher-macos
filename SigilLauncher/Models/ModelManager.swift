import Foundation

class ModelManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var isDownloading = false
    @Published var downloadProgress: Double = 0.0
    @Published var error: String?

    private var downloadTask: URLSessionDownloadTask?
    private var destinationURL: URL?
    private var progressHandler: ((Double) -> Void)?
    private var completionHandler: ((Result<URL, Error>) -> Void)?

    static let modelsDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".sigil/models")
    }()

    func modelPath(for model: ModelInfo) -> URL {
        Self.modelsDirectory.appendingPathComponent(model.filename)
    }

    func isModelDownloaded(_ model: ModelInfo) -> Bool {
        FileManager.default.fileExists(atPath: modelPath(for: model).path)
    }

    func downloadModel(_ model: ModelInfo) async throws -> URL {
        let dest = modelPath(for: model)

        // Already downloaded
        if FileManager.default.fileExists(atPath: dest.path) {
            return dest
        }

        // Create directory
        try FileManager.default.createDirectory(at: Self.modelsDirectory, withIntermediateDirectories: true)

        guard let url = URL(string: model.downloadURL) else {
            throw URLError(.badURL)
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.destinationURL = dest
            self.completionHandler = { result in
                continuation.resume(with: result)
            }

            let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
            let task = session.downloadTask(with: url)

            DispatchQueue.main.async {
                self.isDownloading = true
                self.downloadProgress = 0.0
                self.error = nil
            }

            self.downloadTask = task
            task.resume()
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        DispatchQueue.main.async {
            self.isDownloading = false
            self.downloadProgress = 0.0
        }
    }

    // MARK: - URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let dest = destinationURL else { return }
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            DispatchQueue.main.async {
                self.isDownloading = false
                self.downloadProgress = 1.0
            }
            completionHandler?(.success(dest))
        } catch {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.error = error.localizedDescription
            }
            completionHandler?(.failure(error))
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            DispatchQueue.main.async {
                self.downloadProgress = progress
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            DispatchQueue.main.async {
                self.isDownloading = false
                self.error = error.localizedDescription
            }
            completionHandler?(.failure(error))
        }
    }
}
