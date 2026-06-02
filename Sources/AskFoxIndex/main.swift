import AskFoxCore
import Foundation

@main
struct AskFoxIndexMain {
    static func main() async {
        let env = ProcessInfo.processInfo.environment

        let vaultPath = env["ASKFOX_VAULT"] ?? (NSHomeDirectory() + "/Documents/Fox")
        let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: vaultURL.path, isDirectory: &isDir), isDir.boolValue else {
            FileHandle.standardError.write(Data("error: vault not found at \(vaultURL.path)\n".utf8))
            exit(1)
        }

        let baseURLString = env["ASKFOX_BASE_URL"] ?? "http://localhost:1234/v1"
        guard let baseURL = URL(string: baseURLString) else {
            FileHandle.standardError.write(Data("error: invalid base URL \(baseURLString)\n".utf8))
            exit(1)
        }

        let embeddingModel = env["ASKFOX_EMBEDDING_MODEL"] ?? "text-embedding-nomic-embed-text-v1.5"
        let chatModel = env["ASKFOX_CHAT_MODEL"] ?? "google/gemma-4-e4b"

        let client = OpenAIClient(
            apiKey: "",
            baseURL: baseURL,
            embeddingModel: embeddingModel,
            chatModel: chatModel,
            chatAPIKey: "",
            chatBaseURL: baseURL
        )

        do {
            let store = try VectorStore.defaultStore()
            let indexer = VaultIndexer(vaultURL: vaultURL, client: client, store: store)

            print("Indexing \(vaultURL.path) → \(store.fileURL.path)")
            print("Endpoint: \(baseURL.absoluteString) embed=\(embeddingModel)")
            let progress = try await indexer.indexAll { line in
                print("  " + line)
            }
            print("Done. files scanned=\(progress.filesScanned) reindexed=\(progress.filesReindexed) chunks embedded=\(progress.chunksEmbedded)")
        } catch {
            FileHandle.standardError.write(Data("error: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
