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

    private var currentTask: Task<Void, Never>?

    init(settings: AppSettings) {
        self.settings = settings
        self.apiKey = KeychainStore.load() ?? ""
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

    private func makeClient() -> OpenAIClient {
        OpenAIClient(
            apiKey: apiKey,
            embeddingModel: settings.embeddingModel,
            chatModel: settings.chatModel
        )
    }

    func ask() {
        let q = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        guard !apiKey.isEmpty else {
            lastError = "Set your OpenAI API key in Settings first."
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
        guard !apiKey.isEmpty else {
            lastError = "Set your OpenAI API key in Settings first."
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
