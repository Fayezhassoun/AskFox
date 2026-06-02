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

    private var currentTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
    }

    private func makeClient() -> OpenAIClient {
        let url = URL(string: settings.lmStudioBaseURL) ?? URL(string: AppSettings.defaultLMStudioBaseURL)!
        return OpenAIClient(
            apiKey: "",
            baseURL: url,
            embeddingModel: settings.embeddingModel,
            chatModel: settings.chatModel,
            chatAPIKey: "",
            chatBaseURL: url
        )
    }

    func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        if settings.lmStudioBaseURL.isEmpty {
            lastError = "LM Studio endpoint is empty. Set it from the menu."
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
