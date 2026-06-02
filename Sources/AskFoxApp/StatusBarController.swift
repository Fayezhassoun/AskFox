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

        let providerMenu = NSMenu(title: "Chat Provider")
        for provider in ChatProvider.allCases {
            let item = NSMenuItem(title: provider.displayName, action: #selector(selectChatProvider(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = provider.rawValue
            item.state = (state.settings.chatProvider == provider) ? .on : .off
            providerMenu.addItem(item)
        }
        let providerParent = NSMenuItem(title: "Chat Provider: \(state.settings.chatProvider.displayName) (\(state.settings.chatModel))", action: nil, keyEquivalent: "")
        providerParent.submenu = providerMenu
        menu.addItem(providerParent)

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
