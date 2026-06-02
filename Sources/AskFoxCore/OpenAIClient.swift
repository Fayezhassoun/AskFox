import Foundation

public enum OpenAIError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding(detail: String, body: String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "API key is missing."
        case .http(let status, let body):
            return "HTTP \(status): \(body.prefix(300))"
        case .decoding(let detail, let body):
            return "Decode failed (\(detail)). Body: \(body.prefix(400))"
        case .empty:
            return "Provider returned an empty response."
        }
    }
}

public struct OpenAIClient: Sendable {
    public let apiKey: String
    public let baseURL: URL
    public let embeddingModel: String
    public let chatModel: String
    public let chatAPIKey: String
    public let chatBaseURL: URL
    public let session: URLSession

    public init(
        apiKey: String,
        baseURL: URL = URL(string: "https://api.openai.com/v1")!,
        embeddingModel: String = "text-embedding-3-small",
        chatModel: String = "gpt-4o-mini",
        chatAPIKey: String? = nil,
        chatBaseURL: URL? = nil,
        session: URLSession = .shared
    ) {
        self.apiKey = apiKey
        self.baseURL = baseURL
        self.embeddingModel = embeddingModel
        self.chatModel = chatModel
        self.chatAPIKey = chatAPIKey ?? apiKey
        self.chatBaseURL = chatBaseURL ?? baseURL
        self.session = session
    }

    public func embed(_ inputs: [String]) async throws -> [[Float]] {
        guard !inputs.isEmpty else { return [] }

        let url = baseURL.appendingPathComponent("embeddings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        if !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": embeddingModel,
            "input": inputs
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try Self.check(response: response, data: data)

        struct EmbeddingResponse: Decodable {
            struct Item: Decodable { let embedding: [Float] }
            let data: [Item]
        }

        do {
            let decoded = try JSONDecoder().decode(EmbeddingResponse.self, from: data)
            return decoded.data.map(\.embedding)
        } catch {
            throw OpenAIError.decoding(detail: error.localizedDescription, body: String(data: data, encoding: .utf8) ?? "")
        }
    }

    /// Non-streaming chat. Kept for callers that don't need token-by-token output.
    public func chat(systemPrompt: String, userPrompt: String, temperature: Double = 0.2) async throws -> String {
        var collected = ""
        for try await token in chatStream(systemPrompt: systemPrompt, userPrompt: userPrompt, temperature: temperature) {
            collected += token
        }
        return collected
    }

    /// Streaming chat via Server-Sent Events. Yields content deltas as they arrive.
    /// Yields empty strings for the time-to-first-token slot; the *real* first token
    /// arrives in well under a second on local LM Studio.
    public func chatStream(
        systemPrompt: String,
        userPrompt: String,
        temperature: Double = 0.2
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = chatBaseURL.appendingPathComponent("chat/completions")
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    if !chatAPIKey.isEmpty {
                        request.setValue("Bearer \(chatAPIKey)", forHTTPHeaderField: "Authorization")
                    }
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 120

                    let body: [String: Any] = [
                        "model": chatModel,
                        "temperature": temperature,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": userPrompt]
                        ]
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await session.bytes(for: request)
                    try Self.checkStream(response: response)

                    var sawAnyToken = false
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        let trimmed = line.trimmingCharacters(in: .whitespaces)
                        guard trimmed.hasPrefix("data:") else { continue }
                        let payload = trimmed.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let data = payload.data(using: .utf8) else { continue }
                        if let token = Self.extractContent(from: data) {
                            if !token.isEmpty { sawAnyToken = true }
                            continuation.yield(token)
                        }
                    }

                    if !sawAnyToken {
                        throw OpenAIError.empty
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    private static func extractContent(from data: Data) -> String? {
        struct Chunk: Decodable {
            struct Choice: Decodable {
                struct Delta: Decodable { let content: String? }
                let delta: Delta
            }
            let choices: [Choice]
        }
        do {
            let decoded = try JSONDecoder().decode(Chunk.self, from: data)
            return decoded.choices.first?.delta.content
        } catch {
            // Some providers send keepalive comments as the only payload. Ignore decode failures.
            return nil
        }
    }

    private static func check(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.http(status: http.statusCode, body: body)
        }
    }

    private static func checkStream(response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIError.http(status: http.statusCode, body: "Streaming endpoint returned non-2xx.")
        }
    }
}
