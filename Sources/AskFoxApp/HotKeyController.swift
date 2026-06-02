import AppKit
import Carbon.HIToolbox

@MainActor
final class HotKeyController {
    private let windowController: SearchWindowController
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    init(windowController: SearchWindowController) {
        self.windowController = windowController
    }

    func start() {
        let signature: OSType = 0x41534B46 // 'ASKF'
        let id = EventHotKeyID(signature: signature, id: 1)

        // ⌥⌘Space
        let keyCode = UInt32(kVK_Space)
        let modifiers = UInt32(cmdKey | optionKey)

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let context = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    UInt32(kEventParamDirectObject),
                    UInt32(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                if status == noErr {
                    Task { @MainActor in
                        controller.windowController.toggle()
                    }
                }
                return noErr
            },
            1,
            &eventType,
            context,
            &eventHandler
        )

        RegisterEventHotKey(
            keyCode,
            modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
