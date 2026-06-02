import Foundation
import Accelerate

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

/// Precomputed, flat search index. Built lazily from a `VectorIndex` and
/// reused across calls. Accelerate/vDSP gives us a single fused pass per
/// query — comfortable up to ~100k chunks.
public struct FlatSearchIndex: Sendable {
    public let dimension: Int
    public let chunkCount: Int
    private let flat: [Float]        // chunkCount × dimension, row-major
    private let norms: [Float]       // precomputed L2 norms
    private let chunkRefs: [ChunkRef]

    struct ChunkRef: Sendable {
        let path: String
        let chunkIndex: Int
    }

    public init(from index: VectorIndex) {
        var refs: [ChunkRef] = []
        refs.reserveCapacity(index.files.values.reduce(0) { $0 + $1.chunks.count })
        for (path, file) in index.files {
            for i in 0..<file.chunks.count {
                refs.append(ChunkRef(path: path, chunkIndex: i))
            }
        }

        let dim = refs.first.map { index.files[$0.path]!.chunks[$0.chunkIndex].embedding.count } ?? 0
        var flat = [Float](repeating: 0, count: refs.count * max(dim, 1))
        var norms = [Float](repeating: 0, count: refs.count)

        if dim > 0 {
            flat.withUnsafeMutableBufferPointer { flatBuf in
                let flatPtr = flatBuf.baseAddress!
                for (i, ref) in refs.enumerated() {
                    let emb = index.files[ref.path]!.chunks[ref.chunkIndex].embedding
                    let dst = flatPtr.advanced(by: i * dim)
                    emb.withUnsafeBufferPointer { src in
                        if let base = src.baseAddress {
                            memcpy(dst, base, dim * MemoryLayout<Float>.size)
                        }
                    }
                }
            }
            norms.withUnsafeMutableBufferPointer { normBuf in
                let normPtr = normBuf.baseAddress!
                flat.withUnsafeBufferPointer { flatBuf in
                    let flatPtr = flatBuf.baseAddress!
                    for i in 0..<refs.count {
                        vDSP_svesq(flatPtr.advanced(by: i * dim), 1, normPtr.advanced(by: i), vDSP_Length(dim))
                    }
                }
                // vDSP_svesq gave us sum-of-squares; sqrt in place to get L2 norms.
                var i = 0
                let n = refs.count
                while i < n {
                    var v = normPtr[i]
                    v = sqrt(v)
                    normPtr[i] = v
                    i += 1
                }
            }
        }

        self.dimension = dim
        self.chunkCount = refs.count
        self.flat = flat
        self.norms = norms
        self.chunkRefs = refs
    }

    public func search(query: [Float], topK: Int, sourceIndex: VectorIndex) -> [SearchHit] {
        guard dimension > 0, query.count == dimension, !chunkRefs.isEmpty, topK > 0 else { return [] }

        let queryNorm = sqrt(query.reduce(0) { $0 + $1 * $1 })
        guard queryNorm > 0 else { return [] }

        var scores = [Float](repeating: 0, count: chunkCount)
        let k = scores.count

        scores.withUnsafeMutableBufferPointer { scoreBuf in
            let scorePtr = scoreBuf.baseAddress!
            query.withUnsafeBufferPointer { qBuf in
                flat.withUnsafeBufferPointer { fBuf in
                    let qPtr = qBuf.baseAddress!
                    let fPtr = fBuf.baseAddress!
                    for i in 0..<chunkCount {
                        var dot: Float = 0
                        vDSP_dotpr(qPtr, 1, fPtr.advanced(by: i * dimension), 1, &dot, vDSP_Length(dimension))
                        let denom = queryNorm * norms[i]
                        scorePtr[i] = denom == 0 ? 0 : dot / denom
                    }
                }
            }
        }

        // Partial top-K via descending sort. With ~50k chunks, full sort is
        // still <5ms; if we ever need it, swap to a heap-based selection.
        var order = [Int](0..<k)
        order.sort { scores[$0] > scores[$1] }
        let take = Swift.min(topK, k)

        var hits: [SearchHit] = []
        hits.reserveCapacity(take)
        for i in 0..<take {
            let idx = order[i]
            let ref = chunkRefs[idx]
            guard let file = sourceIndex.files[ref.path] else { continue }
            let chunk = file.chunks[ref.chunkIndex]
            hits.append(SearchHit(path: ref.path, chunk: chunk, score: scores[idx]))
        }
        return hits
    }
}

public final class VectorStore: @unchecked Sendable {
    public let fileURL: URL
    private var cached: VectorIndex?
    private var cachedFlat: FlatSearchIndex?
    private let lock = NSLock()

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
        lock.lock()
        defer { lock.unlock() }
        if let cached { return cached }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            let empty = VectorIndex(model: defaultModel)
            cached = empty
            cachedFlat = nil
            return empty
        }

        let data = try Data(contentsOf: fileURL)
        let index = try JSONDecoder().decode(VectorIndex.self, from: data)
        cached = index
        cachedFlat = nil
        return index
    }

    public func save(_ index: VectorIndex) throws {
        let dir = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(index)
        try data.write(to: fileURL, options: [.atomic])
        lock.lock()
        cached = index
        cachedFlat = nil
        lock.unlock()
    }

    /// Returns a ready-to-search flat index, building it on first use and caching.
    public func flatSearchIndex(for index: VectorIndex) -> FlatSearchIndex {
        lock.lock()
        if let cachedFlat { lock.unlock(); return cachedFlat }
        lock.unlock()
        let flat = FlatSearchIndex(from: index)
        lock.lock()
        cachedFlat = flat
        lock.unlock()
        return flat
    }

    public static func search(_ index: VectorIndex, queryEmbedding: [Float], topK: Int = 8) -> [SearchHit] {
        // Backwards-compatible static API; uses a temporary flat index.
        let flat = FlatSearchIndex(from: index)
        return flat.search(query: queryEmbedding, topK: topK, sourceIndex: index)
    }
}
