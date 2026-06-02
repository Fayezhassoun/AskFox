import Foundation

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

    init() {
        let defaults = UserDefaults.standard
        let defaultVault = (NSHomeDirectory() as NSString).appendingPathComponent("Documents/Fox")
        self.vaultPath = defaults.string(forKey: "vaultPath") ?? defaultVault
        self.vaultName = defaults.string(forKey: "vaultName") ?? "Fox"
        self.embeddingModel = defaults.string(forKey: "embeddingModel") ?? "text-embedding-3-small"
        self.chatModel = defaults.string(forKey: "chatModel") ?? "gpt-4o-mini"
        self.topK = defaults.integer(forKey: "topK") == 0 ? 8 : defaults.integer(forKey: "topK")
    }

    var vaultURL: URL {
        URL(fileURLWithPath: vaultPath, isDirectory: true)
    }
}
