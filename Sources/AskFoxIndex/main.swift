import AskFoxCore
import Foundation

@main
struct AskFoxIndexMain {
    static func main() async {
        let env = ProcessInfo.processInfo.environment

        let apiKey = env["OPENAI_API_KEY"] ?? ""
        if apiKey.isEmpty {
            FileHandle.standardError.write(Data("error: OPENAI_API_KEY is not set\n".utf8))
            exit(1)
        }

        let vaultPath = env["ASKFOX_VAULT"] ?? (NSHomeDirectory() + "/Documents/Fox")
        let vaultURL = URL(fileURLWithPath: vaultPath, isDirectory: true)

        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: vaultURL.path, isDirectory: &isDir), isDir.boolValue else {
            FileHandle.standardError.write(Data("error: vault not found at \(vaultURL.path)\n".utf8))
            exit(1)
        }

        let embeddingModel = env["ASKFOX_EMBEDDING_MODEL"] ?? "text-embedding-3-small"
        let chatModel = env["ASKFOX_CHAT_MODEL"] ?? "gpt-4o-mini"

        let client = OpenAIClient(apiKey: apiKey, embeddingModel: embeddingModel, chatModel: chatModel)

        do {
            let store = try VectorStore.defaultStore()
            let indexer = VaultIndexer(vaultURL: vaultURL, client: client, store: store)

            print("Indexing \(vaultURL.path) → \(store.fileURL.path)")
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
