import Foundation

enum ChatProvider: String, CaseIterable, Identifiable {
    case openai
    case deepseek
    case lmstudio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        case .lmstudio: return "LM Studio (local)"
        }
    }

    var defaultChatModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .deepseek: return "deepseek-chat"
        case .lmstudio: return "local-model"
        }
    }

    func baseURL(lmStudioOverride: String) -> URL {
        switch self {
        case .openai: return URL(string: "https://api.openai.com/v1")!
        case .deepseek: return URL(string: "https://api.deepseek.com/v1")!
        case .lmstudio: return URL(string: lmStudioOverride) ?? URL(string: "http://localhost:1234/v1")!
        }
    }
}

enum EmbeddingsProvider: String, CaseIterable, Identifiable {
    case openai
    case lmstudio

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .lmstudio: return "LM Studio (local)"
        }
    }

    var defaultEmbeddingModel: String {
        switch self {
        case .openai: return "text-embedding-3-small"
        case .lmstudio: return "nomic-embed-text-v1.5"
        }
    }

    func baseURL(lmStudioOverride: String) -> URL {
        switch self {
        case .openai: return URL(string: "https://api.openai.com/v1")!
        case .lmstudio: return URL(string: lmStudioOverride) ?? URL(string: "http://localhost:1234/v1")!
        }
    }
}

@MainActor
final class AppSettings: ObservableObject {
    @Published var vaultPath: String {
        didSet { UserDefaults.standard.set(vaultPath, forKey: "vaultPath") }
    }
    @Published var vaultName: String {
        didSet { UserDefaults.standard.set(vaultName, forKey: "vaultName") }
    }
    @Published var embeddingModel: String {
        didSet { UserDefaults.standard.set(embeddingModel, forKey: "embeddingModel") }
    }
    @Published var chatModel: String {
        didSet { UserDefaults.standard.set(chatModel, forKey: "chatModel") }
    }
    @Published var topK: Int {
        didSet { UserDefaults.standard.set(topK, forKey: "topK") }
    }
    @Published var chatProvider: ChatProvider {
        didSet {
            UserDefaults.standard.set(chatProvider.rawValue, forKey: "chatProvider")
            chatModel = chatProvider.defaultChatModel
        }
    }
    @Published var embeddingsProvider: EmbeddingsProvider {
        didSet {
            UserDefaults.standard.set(embeddingsProvider.rawValue, forKey: "embeddingsProvider")
            embeddingModel = embeddingsProvider.defaultEmbeddingModel
        }
    }
    @Published var lmStudioBaseURL: String {
        didSet { UserDefaults.standard.set(lmStudioBaseURL, forKey: "lmStudioBaseURL") }
    }

    init() {
        let defaults = UserDefaults.standard
        let defaultVault = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Fox")
        self.vaultPath = defaults.string(forKey: "vaultPath") ?? defaultVault
        self.vaultName = defaults.string(forKey: "vaultName") ?? "Fox"

        let chatProviderRaw = defaults.string(forKey: "chatProvider") ?? ChatProvider.openai.rawValue
        let chat = ChatProvider(rawValue: chatProviderRaw) ?? .openai
        self.chatProvider = chat
        self.chatModel = defaults.string(forKey: "chatModel") ?? chat.defaultChatModel

        let embedProviderRaw = defaults.string(forKey: "embeddingsProvider") ?? EmbeddingsProvider.openai.rawValue
        let embed = EmbeddingsProvider(rawValue: embedProviderRaw) ?? .openai
        self.embeddingsProvider = embed
        self.embeddingModel = defaults.string(forKey: "embeddingModel") ?? embed.defaultEmbeddingModel

        self.lmStudioBaseURL = defaults.string(forKey: "lmStudioBaseURL") ?? "http://localhost:1234/v1"
        self.topK = defaults.integer(forKey: "topK") == 0 ? 8 : defaults.integer(forKey: "topK")
    }

    var vaultURL: URL {
        URL(fileURLWithPath: vaultPath, isDirectory: true)
    }
}
