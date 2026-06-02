import AppKit
import AskFoxCore
import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var question: String = ""
    @Published var answer: String = ""
    @Published var citations: [Citation] = []
    @Published var isAnswering: Bool = false
    @Published var lastError: String?
    @Published var indexStatus: String = ""

    let settings: AppSettings
    private(set) var apiKey: String
    private(set) var deepseekKey: String

    private var currentTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        self.apiKey = KeychainStore.load() ?? ""
        self.deepseekKey = KeychainStore.load(account: KeychainStore.deepseekAccount) ?? ""
    }

    func setAPIKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try KeychainStore.delete()
            } else {
                try KeychainStore.save(trimmed)
            }
            apiKey = trimmed
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setDeepSeekKey(_ value: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            if trimmed.isEmpty {
                try KeychainStore.delete(account: KeychainStore.deepseekAccount)
            } else {
                try KeychainStore.save(trimmed, account: KeychainStore.deepseekAccount)
            }
            deepseekKey = trimmed
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func makeClient() -> OpenAIClient {
        let embedKey: String
        switch settings.embeddingsProvider {
        case .openai: embedKey = apiKey
        case .lmstudio: embedKey = ""
        }
        let embedURL = settings.embeddingsProvider.baseURL(lmStudioOverride: settings.lmStudioBaseURL)

        let chatKey: String
        switch settings.chatProvider {
        case .openai: chatKey = apiKey
        case .deepseek: chatKey = deepseekKey
        case .lmstudio: chatKey = ""
        }
        let chatURL = settings.chatProvider.baseURL(lmStudioOverride: settings.lmStudioBaseURL)

        return OpenAIClient(
            apiKey: embedKey,
            baseURL: embedURL,
            embeddingModel: settings.embeddingModel,
            chatModel: settings.chatModel,
            chatAPIKey: chatKey,
            chatBaseURL: chatURL
        )
    }

    func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        if let blocker = providerBlocker() {
            lastError = blocker
            return
        }

        currentTask?.cancel()
        isAnswering = true
        answer = ""
        citations = []
        lastError = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            do {
                let store = try VectorStore.defaultStore()
                let engine = AnswerEngine(client: makeClient(), store: store, topK: settings.topK)
                let result = try await engine.answer(q)
                await MainActor.run {
                    self.answer = result.answer
                    self.citations = result.citations
                    self.isAnswering = false
                }
            } catch {
                await MainActor.run {
                    self.lastError = error.localizedDescription
                    self.isAnswering = false
                }
            }
        }
    }

    func reindex() {
        if let blocker = providerBlocker(chatRequired: false) {
            lastError = blocker
            return
        }

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: settings.vaultURL.path, isDirectory: &isDir), isDir.boolValue else {
            lastError = "Vault not found at \(settings.vaultURL.path)."
            return
        }

        indexStatus = "Starting…"
        Task { [weak self] in
            guard let self else { return }
            do {
                let store = try VectorStore.defaultStore()
                let indexer = VaultIndexer(
                    vaultURL: settings.vaultURL,
                    client: makeClient(),
                    store: store
                )
                let progress = try await indexer.indexAll { line in
                    Task { @MainActor in
                        self.indexStatus = line
                    }
                }
                await MainActor.run {
                    self.indexStatus = "Indexed \(progress.filesReindexed)/\(progress.filesScanned) files, \(progress.chunksEmbedded) new chunks."
                }
            } catch {
                await MainActor.run {
                    self.lastError = "Index failed: \(error.localizedDescription)"
                    self.indexStatus = ""
                }
            }
        }
    }

    private func providerBlocker(chatRequired: Bool = true) -> String? {
        switch settings.embeddingsProvider {
        case .openai where apiKey.isEmpty:
            return "Embeddings provider is OpenAI but no OpenAI key is set."
        case .lmstudio where settings.lmStudioBaseURL.isEmpty:
            return "Embeddings provider is LM Studio but no endpoint is set."
        default:
            break
        }
        if chatRequired {
            switch settings.chatProvider {
            case .openai where apiKey.isEmpty:
                return "Chat provider is OpenAI but no OpenAI key is set."
            case .deepseek where deepseekKey.isEmpty:
                return "Chat provider is DeepSeek but no DeepSeek key is set."
            case .lmstudio where settings.lmStudioBaseURL.isEmpty:
                return "Chat provider is LM Studio but no endpoint is set."
            default:
                break
            }
        }
        return nil
    }

    func openInObsidian(path: String) {
        let relative = relativePathInVault(path)
        var components = URLComponents()
        components.scheme = "obsidian"
        components.host = "open"
        components.queryItems = [
            URLQueryItem(name: "vault", value: settings.vaultName),
            URLQueryItem(name: "file", value: relative)
        ]
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }

    private func relativePathInVault(_ path: String) -> String {
        let vault = settings.vaultURL.path
        if path.hasPrefix(vault) {
            var relative = String(path.dropFirst(vault.count))
            if relative.hasPrefix("/") {
                relative.removeFirst()
            }
            if relative.hasSuffix(".md") {
                relative.removeLast(3)
            }
            return relative
        }
        return path
    }
}
