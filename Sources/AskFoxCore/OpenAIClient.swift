import Foundation

public enum OpenAIError: LocalizedError {
    case missingAPIKey
    case http(status: Int, body: String)
    case decoding(String)
    case empty

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "OpenAI API key is missing. Set it in AskFox Settings or OPENAI_API_KEY."
        case .http(let status, let body):
            return "OpenAI HTTP \(status): \(body.prefix(300))"
        case .decoding(let detail):
            return "Could not decode OpenAI response: \(detail)"
        case .empty:
            return "OpenAI returned an empty response."
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
        guard !apiKey.isEmpty else { throw OpenAIError.missingAPIKey }
        guard !inputs.isEmpty else { return [] }

        let url = baseURL.appendingPathComponent("embeddings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
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
            throw OpenAIError.decoding(error.localizedDescription)
        }
    }

    public func chat(systemPrompt: String, userPrompt: String, temperature: Double = 0.2) async throws -> String {
        guard !chatAPIKey.isEmpty else { throw OpenAIError.missingAPIKey }

        let url = chatBaseURL.appendingPathComponent("chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(chatAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": chatModel,
            "temperature": temperature,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        try Self.check(response: response, data: data)

        struct ChatResponse: Decodable {
            struct Choice: Decodable {
                struct Message: Decodable { let content: String? }
                let message: Message
            }
            let choices: [Choice]
        }

        do {
            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            guard let content = decoded.choices.first?.message.content, !content.isEmpty else {
                throw OpenAIError.empty
            }
            return content
        } catch let error as OpenAIError {
            throw error
        } catch {
            throw OpenAIError.decoding(error.localizedDescription)
        }
    }

    private static func check(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw OpenAIError.http(status: http.statusCode, body: body)
        }
    }
}
