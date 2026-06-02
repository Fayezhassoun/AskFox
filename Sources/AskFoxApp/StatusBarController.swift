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

        let key = state.apiKey.isEmpty ? "Set OpenAI API Key…" : "Change OpenAI API Key…"
        let keyItem = NSMenuItem(title: key, action: #selector(promptAPIKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)

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
        let alert = NSAlert()
        alert.messageText = "OpenAI API Key"
        alert.informativeText = "Stored in macOS Keychain. Leave blank to remove."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        input.stringValue = state.apiKey
        alert.accessoryView = input

        if alert.runModal() == .alertFirstButtonReturn {
            state.setAPIKey(input.stringValue)
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
