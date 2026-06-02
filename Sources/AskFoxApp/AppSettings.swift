import Foundation

enum ChatProvider: String, CaseIterable, Identifiable {
    case openai
    case deepseek

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        }
    }

    var defaultChatModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .deepseek: return "deepseek-chat"
        }
    }

    var baseURL: URL {
        switch self {
        case .openai: return URL(string: "https://api.openai.com/v1")!
        case .deepseek: return URL(string: "https://api.deepseek.com/v1")!
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
            if !UserDefaults.standard.bool(forKey: "chatModelManuallySet") {
                chatModel = chatProvider.defaultChatModel
            }
        }
    }

    init() {
        let defaults = UserDefaults.standard
        let defaultVault = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Fox")
        self.vaultPath = defaults.string(forKey: "vaultPath") ?? defaultVault
        self.vaultName = defaults.string(forKey: "vaultName") ?? "Fox"
        self.embeddingModel = defaults.string(forKey: "embeddingModel") ?? "text-embedding-3-small"
        let providerRaw = defaults.string(forKey: "chatProvider") ?? ChatProvider.openai.rawValue
        let provider = ChatProvider(rawValue: providerRaw) ?? .openai
        self.chatProvider = provider
        self.chatModel = defaults.string(forKey: "chatModel") ?? provider.defaultChatModel
        self.topK = defaults.integer(forKey: "topK") == 0 ? 8 : defaults.integer(forKey: "topK")
    }

    var vaultURL: URL {
        URL(fileURLWithPath: vaultPath, isDirectory: true)
    }
}
