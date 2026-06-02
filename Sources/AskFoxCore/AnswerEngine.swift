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
        let index = try store.load(defaultModel: client.embeddingModel)
        let queryEmbeddings = try await client.embed([question])
        guard let queryEmbedding = queryEmbeddings.first else {
            return AnswerResult(answer: "Could not embed question.", citations: [])
        }

        let hits = VectorStore.search(index, queryEmbedding: queryEmbedding, topK: topK)
        guard !hits.isEmpty else {
            return AnswerResult(answer: "Vault index is empty. Run AskFoxIndex first.", citations: [])
        }

        let context = hits.enumerated().map { idx, hit in
            "[\(idx + 1)] \(displayPath(hit.path)) — \(hit.chunk.heading.isEmpty ? "(top)" : hit.chunk.heading)\n\(hit.chunk.text)"
        }.joined(separator: "\n\n---\n\n")

        let system = """
        You are AskFox, a precise assistant that answers questions strictly from the user's Obsidian vault.
        Rules:
        - Only use facts from the provided vault excerpts. If the answer is not in them, say so plainly.
        - Cite sources inline with bracketed numbers like [1] [2] matching the excerpts you used.
        - Be concise. Markdown is welcome. No filler.
        """

        let user = """
        Vault excerpts:

        \(context)

        Question: \(question)
        """

        let answer = try await client.chat(systemPrompt: system, userPrompt: user)

        let citations = hits.map { Citation(path: $0.path, heading: $0.chunk.heading, score: $0.score) }
        return AnswerResult(answer: answer, citations: citations)
    }

    private func displayPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + String(path.dropFirst(home.count))
        }
        return path
    }
}
