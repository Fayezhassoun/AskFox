import Foundation

public struct VaultIndexer: Sendable {
    public let vaultURL: URL
    public let client: OpenAIClient
    public let store: VectorStore
    public let batchSize: Int

    public init(vaultURL: URL, client: OpenAIClient, store: VectorStore, batchSize: Int = 64) {
        self.vaultURL = vaultURL
        self.client = client
        self.store = store
        self.batchSize = batchSize
    }

    public struct Progress: Sendable {
        public let filesScanned: Int
        public let filesReindexed: Int
        public let chunksEmbedded: Int
    }

    public func indexAll(log: @escaping @Sendable (String) -> Void = { _ in }) async throws -> Progress {
        let files = try Self.markdownFiles(in: vaultURL)
        var index = try store.load(defaultModel: client.embeddingModel)
        index.model = client.embeddingModel

        var reindexed = 0
        var chunksEmbedded = 0

        let livePaths = Set(files.map(\.path))
        for stalePath in index.files.keys where !livePaths.contains(stalePath) {
            index.files.removeValue(forKey: stalePath)
        }

        for fileURL in files {
            let attrs = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

            if let existing = index.files[fileURL.path], abs(existing.mtime - mtime) < 1.0 {
                continue
            }

            let raw = try String(contentsOf: fileURL, encoding: .utf8)
            let chunks = NoteChunker.chunk(markdown: raw)
            guard !chunks.isEmpty else {
                index.files[fileURL.path] = StoredFile(mtime: mtime, chunks: [])
                continue
            }

            log("Embedding \(chunks.count) chunks: \(fileURL.lastPathComponent)")

            var stored: [StoredChunk] = []
            for batch in chunks.chunked(into: batchSize) {
                let inputs = batch.map { chunk -> String in
                    "Heading: \(chunk.heading)\n\n\(chunk.text)"
                }
                let embeddings = try await client.embed(inputs)
                for (chunk, embedding) in zip(batch, embeddings) {
                    stored.append(StoredChunk(
                        heading: chunk.heading,
                        text: chunk.text,
                        charOffset: chunk.charOffset,
                        embedding: embedding
                    ))
                }
                chunksEmbedded += batch.count
            }

            index.files[fileURL.path] = StoredFile(mtime: mtime, chunks: stored)
            reindexed += 1

            try store.save(index)
        }

        return Progress(filesScanned: files.count, filesReindexed: reindexed, chunksEmbedded: chunksEmbedded)
    }

    public static func markdownFiles(in vaultURL: URL) throws -> [URL] {
        let enumerator = FileManager.default.enumerator(
            at: vaultURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        var results: [URL] = []
        while let url = enumerator?.nextObject() as? URL {
            guard url.pathExtension.lowercased() == "md" else { continue }
            let isRegular = (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) ?? false
            guard isRegular else { continue }
            results.append(url)
        }
        return results.sorted { $0.path < $1.path }
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index = end
        }
        return result
    }
}
