import Foundation

public struct Citation: Sendable, Equatable {
    public let path: String
    public let heading: String
    public let score: Float
}

public struct AnswerResult: Sendable {
    public let answer: String
    public let citations: [Citation]
}

public struct AnswerEngine: Sendable {
    public let client: OpenAIClient
    public let store: VectorStore
    public let topK: Int

    public init(client: OpenAIClient, store: VectorStore, topK: Int = 8) {
        self.client = client
        self.store = store
        self.topK = topK
    }

    public func answer(_ question: String) async throws -> AnswerResult {
        let (index, flat) = try await prepareIndex()
        let hits = try await retrieve(question: question, index: index, flat: flat)
        guard !hits.isEmpty else {
            return AnswerResult(answer: "Vault index is empty. Run AskFoxIndex first.", citations: [])
        }
        let answer = try await generateAnswer(question: question, hits: hits)
        let citations = hits.map { Citation(path: $0.path, heading: $0.chunk.heading, score: $0.score) }
        return AnswerResult(answer: answer, citations: citations)
    }

    /// Streams the answer token-by-token while emitting citations as soon as retrieval finishes.
    public func answerStream(_ question: String) -> AsyncThrowingStream<AnswerEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (index, flat) = try await prepareIndex()
                    let hits = try await retrieve(question: question, index: index, flat: flat)
                    if hits.isEmpty {
                        continuation.yield(.token("Vault index is empty. Run AskFoxIndex first."))
                        continuation.yield(.done([]))
                        continuation.finish()
                        return
                    }
                    let citations = hits.map { Citation(path: $0.path, heading: $0.chunk.heading, score: $0.score) }
                    continuation.yield(.retrieved(citations))

                    let context = formatContext(hits)
                    let system = Self.systemPrompt
                    let user = """
                    Vault excerpts:

                    \(context)

                    Question: \(question)
                    """
                    for try await token in client.chatStream(systemPrompt: system, userPrompt: user) {
                        if Task.isCancelled { break }
                        continuation.yield(.token(token))
                    }
                    continuation.yield(.done(citations))
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: - Internals

    private struct Prepared {
        let index: VectorIndex
        let flat: FlatSearchIndex
    }

    private func prepareIndex() async throws -> (VectorIndex, FlatSearchIndex) {
        // load() is sync; wrapping in a task lets it overlap with embed() in retrieve().
        let indexTask = Task.detached(priority: .userInitiated) { [store, client] in
            let index = try store.load(defaultModel: client.embeddingModel)
            return (index, store.flatSearchIndex(for: index))
        }
        return try await indexTask.value
    }

    private func retrieve(
        question: String,
        index: VectorIndex,
        flat: FlatSearchIndex
    ) async throws -> [SearchHit] {
        let queryEmbeddings = try await client.embed([question])
        guard let queryEmbedding = queryEmbeddings.first else { return [] }
        return flat.search(query: queryEmbedding, topK: topK, sourceIndex: index)
    }

    private func generateAnswer(question: String, hits: [SearchHit]) async throws -> String {
        let context = formatContext(hits)
        let user = """
        Vault excerpts:

        \(context)

        Question: \(question)
        """
        return try await client.chat(systemPrompt: Self.systemPrompt, userPrompt: user)
    }

    private func formatContext(_ hits: [SearchHit]) -> String {
        hits.enumerated().map { idx, hit in
            "[\(idx + 1)] \(displayPath(hit.path)) — \(hit.chunk.heading.isEmpty ? "(top)" : hit.chunk.heading)\n\(hit.chunk.text)"
        }.joined(separator: "\n\n---\n\n")
    }

    private static let systemPrompt = """
    You are AskFox, a precise assistant that answers questions strictly from the user's Obsidian vault.
    Rules:
    - Only use facts from the provided vault excerpts. If the answer is not in them, say so plainly.
    - Cite sources inline with bracketed numbers like [1] [2] matching the excerpts you used.
    - Be concise. Markdown is welcome. No filler.
    """

    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }
}

public enum AnswerEvent: Sendable {
    case retrieved([Citation])
    case token(String)
    case done([Citation])
}

/// Thread-safe LRU cache keyed by question text. Bounded by entry count;
/// each entry stores the final answer plus its citations.
public final class AnswerCache: @unchecked Sendable {
    private struct Entry: Sendable {
        let answer: String
        let citations: [Citation]
    }

    private let limit: Int
    private var order: [String] = []                 // most-recent at end
    private var entries: [String: Entry] = [:]
    private let lock = NSLock()

    public init(limit: Int = 200) {
        self.limit = limit
    }

    public func get(_ question: String) -> (answer: String, citations: [Citation])? {
        let key = Self.normalize(question)
        lock.lock()
        defer { lock.unlock() }
        guard let entry = entries[key] else { return nil }
        if let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
            order.append(key)
        }
        return (entry.answer, entry.citations)
    }

    public func put(_ question: String, answer: String, citations: [Citation]) {
        let key = Self.normalize(question)
        lock.lock()
        defer { lock.unlock() }
        if entries[key] != nil, let idx = order.firstIndex(of: key) {
            order.remove(at: idx)
        }
        order.append(key)
        entries[key] = Entry(answer: answer, citations: citations)
        while order.count > limit, let oldest = order.first {
            order.removeFirst()
            entries.removeValue(forKey: oldest)
        }
    }

    private static func normalize(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
