import AppKit
import AskFoxCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let state: AppState
    private let windowController: SearchWindowController
    private let menu = NSMenu()

    init(state: AppState, windowController: SearchWindowController) {
        self.state = state
        self.windowController = windowController
        super.init()
        configure()
    }

    private func configure() {
        statusItem.button?.image = NSImage(systemSymbolName: "sparkle.magnifyingglass", accessibilityDescription: "AskFox")
        menu.delegate = self
        menu.autoenablesItems = false
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        menu.removeAllItems()

        let ask = NSMenuItem(title: "Ask (⌥⌘Space)", action: #selector(openSearch), keyEquivalent: "")
        ask.target = self
        menu.addItem(ask)

        let reindex = NSMenuItem(title: "Reindex Vault", action: #selector(reindex), keyEquivalent: "")
        reindex.target = self
        menu.addItem(reindex)

        menu.addItem(NSMenuItem.separator())

        let endpoint = NSMenuItem(title: "LM Studio Endpoint: \(state.settings.lmStudioBaseURL)", action: #selector(promptLMStudioURL), keyEquivalent: "")
        endpoint.target = self
        menu.addItem(endpoint)

        let chatModel = NSMenuItem(title: "Chat Model: \(state.settings.chatModel)", action: #selector(promptChatModel), keyEquivalent: "")
        chatModel.target = self
        menu.addItem(chatModel)

        let embedModel = NSMenuItem(title: "Embedding Model: \(state.settings.embeddingModel)", action: #selector(promptEmbeddingModel), keyEquivalent: "")
        embedModel.target = self
        menu.addItem(embedModel)

        let vault = NSMenuItem(title: "Vault: \(state.settings.vaultPath)", action: #selector(promptVaultPath), keyEquivalent: "")
        vault.target = self
        menu.addItem(vault)

        menu.addItem(NSMenuItem.separator())

        let status = NSMenuItem(
            title: state.indexStatus.isEmpty ? "Ready" : state.indexStatus,
            action: nil,
            keyEquivalent: ""
        )
        status.isEnabled = false
        menu.addItem(status)

        menu.addItem(NSMenuItem.separator())

        let quit = NSMenuItem(title: "Quit AskFox", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    @objc private func openSearch() {
        windowController.show()
    }

    @objc private func reindex() {
        state.reindex()
    }

    @objc private func promptLMStudioURL() {
        promptText(
            title: "LM Studio Endpoint",
            info: "OpenAI-compatible base URL. Default: \(AppSettings.defaultLMStudioBaseURL)",
            current: state.settings.lmStudioBaseURL
        ) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.settings.lmStudioBaseURL = trimmed
            }
        }
    }

    @objc private func promptChatModel() {
        promptText(
            title: "Chat Model",
            info: "Model identifier loaded in LM Studio. Example: \(AppSettings.defaultChatModel)",
            current: state.settings.chatModel
        ) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.settings.chatModel = trimmed
            }
        }
    }

    @objc private func promptEmbeddingModel() {
        promptText(
            title: "Embedding Model",
            info: "Embedding model loaded in LM Studio. Example: \(AppSettings.defaultEmbeddingModel)",
            current: state.settings.embeddingModel
        ) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.settings.embeddingModel = trimmed
            }
        }
    }

    private func promptText(title: String, info: String, current: String, save: (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 420, height: 24))
        input.stringValue = current
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            save(input.stringValue)
        }
    }

    @objc private func promptVaultPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Pick your Obsidian vault folder"
        panel.directoryURL = state.settings.vaultURL

        if panel.runModal() == .OK, let url = panel.url {
            state.settings.vaultPath = url.path
            state.settings.vaultName = url.lastPathComponent
        }
    }
}
