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

        let openaiTitle = state.apiKey.isEmpty ? "Set OpenAI API Key…" : "Change OpenAI API Key…"
        let openaiItem = NSMenuItem(title: openaiTitle, action: #selector(promptAPIKey), keyEquivalent: "")
        openaiItem.target = self
        menu.addItem(openaiItem)

        let deepseekTitle = state.deepseekKey.isEmpty ? "Set DeepSeek API Key…" : "Change DeepSeek API Key…"
        let deepseekItem = NSMenuItem(title: deepseekTitle, action: #selector(promptDeepSeekKey), keyEquivalent: "")
        deepseekItem.target = self
        menu.addItem(deepseekItem)

        let chatMenu = NSMenu(title: "Chat Provider")
        for provider in ChatProvider.allCases {
            let item = NSMenuItem(title: provider.displayName, action: #selector(selectChatProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.rawValue
            item.state = (state.settings.chatProvider == provider) ? .on : .off
            chatMenu.addItem(item)
        }
        let chatParent = NSMenuItem(title: "Chat Provider: \(state.settings.chatProvider.displayName) (\(state.settings.chatModel))", action: nil, keyEquivalent: "")
        chatParent.submenu = chatMenu
        menu.addItem(chatParent)

        let embedMenu = NSMenu(title: "Embeddings Provider")
        for provider in EmbeddingsProvider.allCases {
            let item = NSMenuItem(title: provider.displayName, action: #selector(selectEmbeddingsProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.rawValue
            item.state = (state.settings.embeddingsProvider == provider) ? .on : .off
            embedMenu.addItem(item)
        }
        let embedParent = NSMenuItem(title: "Embeddings Provider: \(state.settings.embeddingsProvider.displayName) (\(state.settings.embeddingModel))", action: nil, keyEquivalent: "")
        embedParent.submenu = embedMenu
        menu.addItem(embedParent)

        let lmItem = NSMenuItem(title: "LM Studio Endpoint: \(state.settings.lmStudioBaseURL)", action: #selector(promptLMStudioURL), keyEquivalent: "")
        lmItem.target = self
        menu.addItem(lmItem)

        let chatModelItem = NSMenuItem(title: "Chat Model…", action: #selector(promptChatModel), keyEquivalent: "")
        chatModelItem.target = self
        menu.addItem(chatModelItem)

        let embedModelItem = NSMenuItem(title: "Embedding Model…", action: #selector(promptEmbeddingModel), keyEquivalent: "")
        embedModelItem.target = self
        menu.addItem(embedModelItem)

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

    @objc private func promptAPIKey() {
        promptKey(
            title: "OpenAI API Key",
            info: "Used for embeddings (required) and OpenAI chat. Stored in macOS Keychain. Leave blank to remove.",
            current: state.apiKey
        ) { state.setAPIKey($0) }
    }

    @objc private func promptDeepSeekKey() {
        promptKey(
            title: "DeepSeek API Key",
            info: "Used when Chat Provider is DeepSeek. Stored in macOS Keychain. Leave blank to remove.",
            current: state.deepseekKey
        ) { state.setDeepSeekKey($0) }
    }

    private func promptKey(title: String, info: String, current: String, save: (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
        input.stringValue = current
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            save(input.stringValue)
        }
    }

    @objc private func selectChatProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = ChatProvider(rawValue: raw) else {
            return
        }
        state.settings.chatProvider = provider
    }

    @objc private func selectEmbeddingsProvider(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let provider = EmbeddingsProvider(rawValue: raw) else {
            return
        }
        state.settings.embeddingsProvider = provider
    }

    @objc private func promptLMStudioURL() {
        promptText(
            title: "LM Studio Endpoint",
            info: "OpenAI-compatible base URL. Default: http://localhost:1234/v1",
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
            info: "Model identifier the chat provider expects. LM Studio accepts any name when one chat model is loaded.",
            current: state.settings.chatModel
        ) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.settings.chatModel = trimmed
                UserDefaults.standard.set(trimmed, forKey: "chatModel")
            }
        }
    }

    @objc private func promptEmbeddingModel() {
        promptText(
            title: "Embedding Model",
            info: "Model identifier for embeddings. LM Studio example: nomic-embed-text-v1.5",
            current: state.settings.embeddingModel
        ) { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                state.settings.embeddingModel = trimmed
                UserDefaults.standard.set(trimmed, forKey: "embeddingModel")
            }
        }
    }

    private func promptText(title: String, info: String, current: String, save: (String) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = info
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 360, height: 24))
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
