import Foundation

@MainActor
final class AppSettings: ObservableObject {
    static let defaultLMStudioBaseURL = "http://localhost:1234/v1"
    static let defaultChatModel = "google/gemma-4-e4b"
    static let defaultEmbeddingModel = "text-embedding-nomic-embed-text-v1.5"

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
    @Published var lmStudioBaseURL: String {
        didSet { UserDefaults.standard.set(lmStudioBaseURL, forKey: "lmStudioBaseURL") }
    }

    init() {
        let defaults = UserDefaults.standard

        let configVersion = defaults.integer(forKey: "configVersion")
        if configVersion < 2 {
            defaults.removeObject(forKey: "chatModel")
            defaults.removeObject(forKey: "embeddingModel")
            defaults.removeObject(forKey: "chatProvider")
            defaults.removeObject(forKey: "embeddingsProvider")
            defaults.set(2, forKey: "configVersion")
        }

        let defaultVault = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Fox")
        self.vaultPath = defaults.string(forKey: "vaultPath") ?? defaultVault
        self.vaultName = defaults.string(forKey: "vaultName") ?? "Fox"
        self.chatModel = defaults.string(forKey: "chatModel") ?? Self.defaultChatModel
        self.embeddingModel = defaults.string(forKey: "embeddingModel") ?? Self.defaultEmbeddingModel
        self.lmStudioBaseURL = defaults.string(forKey: "lmStudioBaseURL") ?? Self.defaultLMStudioBaseURL
        self.topK = defaults.integer(forKey: "topK") == 0 ? 8 : defaults.integer(forKey: "topK")
    }

    var vaultURL: URL {
        URL(fileURLWithPath: vaultPath, isDirectory: true)
    }
}
