import AppKit
import AskFoxCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var settings: AppSettings?
    private var state: AppState?
    private var windowController: SearchWindowController?
    private var statusBar: StatusBarController?
    private var hotKey: HotKeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = AppSettings()
        let state = AppState(settings: settings)
        let windowController = SearchWindowController(state: state)

        self.settings = settings
        self.state = state
        self.windowController = windowController
        self.statusBar = StatusBarController(state: state, windowController: windowController)

        let hotKey = HotKeyController(windowController: windowController)
        hotKey.start()
        self.hotKey = hotKey
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotKey?.stop()
    }
}
