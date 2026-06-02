import Foundation

public struct StoredChunk: Codable, Sendable, Equatable {
    public let heading: String
    public let text: String
    public let charOffset: Int
    public let embedding: [Float]

    public init(heading: String, text: String, charOffset: Int, embedding: [Float]) {
        self.heading = heading
        self.text = text
        self.charOffset = charOffset
        self.embedding = embedding
    }
}

public struct StoredFile: Codable, Sendable, Equatable {
    public var mtime: TimeInterval
    public var chunks: [StoredChunk]

    public init(mtime: TimeInterval, chunks: [StoredChunk]) {
        self.mtime = mtime
        self.chunks = chunks
    }
}

public struct SearchHit: Sendable {
    public let path: String
    public let chunk: StoredChunk
    public let score: Float

    public init(path: String, chunk: StoredChunk, score: Float) {
        self.path = path
        self.chunk = chunk
        self.score = score
    }
}

public struct VectorIndex: Codable, Sendable, Equatable {
    public var version: Int
    public var model: String
    public var files: [String: StoredFile]

    public init(version: Int = 1, model: String, files: [String: StoredFile] = [:]) {
        self.version = version
        self.model = model
        self.files = files
    }
}

public final class VectorStore: @unchecked Sendable {
    public let fileURL: URL
    private var cached: VectorIndex?

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public static func defaultStore(appName: String = "AskFox", model: String = "text-embedding-3-small") throws -> VectorStore {
        let baseURL = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let appURL = baseURL.appendingPathComponent(appName, isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)
        return VectorStore(fileURL: appURL.appendingPathComponent("index.json"))
    }

    public func load(defaultModel: String = "text-embedding-3-small") throws -> VectorIndex {
        if let cached { return cached }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let empty = VectorIndex(model: defaultModel)
            cached = empty
            return empty
        }

        let data = try Data(contentsOf: fileURL)
        let index = try JSONDecoder().decode(VectorIndex.self, from: data)
        cached = index
        return index
    }

    public func save(_ index: VectorIndex) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: fileURL, options: [.atomic])
        cached = index
    }

    public static func search(_ index: VectorIndex, queryEmbedding: [Float], topK: Int = 8) -> [SearchHit] {
        var hits: [SearchHit] = []
        hits.reserveCapacity(index.files.values.reduce(0) { $0 + $1.chunks.count })

        for (path, file) in index.files {
            for chunk in file.chunks {
                let score = cosineSimilarity(queryEmbedding, chunk.embedding)
                hits.append(SearchHit(path: path, chunk: chunk, score: score))
            }
        }

        hits.sort { $0.score > $1.score }
        return Array(hits.prefix(topK))
    }

    private static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0..<a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = (normA.squareRoot() * normB.squareRoot())
        return denom == 0 ? 0 : dot / denom
    }
}
