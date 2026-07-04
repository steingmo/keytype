import Carbon
import Foundation

struct HotKeyOption: Identifiable, Hashable {
    let id: String
    let display: String
    let keyCode: UInt32
    let carbonModifiers: UInt32

    static let all: [HotKeyOption] = [
        HotKeyOption(id: "opt-ctrl-x", display: "⌥ ⌃ X",
                     keyCode: UInt32(kVK_ANSI_X),
                     carbonModifiers: UInt32(optionKey | controlKey)),
        HotKeyOption(id: "opt-ctrl-v", display: "⌥ ⌃ V",
                     keyCode: UInt32(kVK_ANSI_V),
                     carbonModifiers: UInt32(optionKey | controlKey)),
        HotKeyOption(id: "opt-cmd-v", display: "⌥ ⌘ V",
                     keyCode: UInt32(kVK_ANSI_V),
                     carbonModifiers: UInt32(optionKey | cmdKey)),
        HotKeyOption(id: "ctrl-shift-v", display: "⌃ ⇧ V",
                     keyCode: UInt32(kVK_ANSI_V),
                     carbonModifiers: UInt32(controlKey | shiftKey)),
        HotKeyOption(id: "opt-ctrl-k", display: "⌥ ⌃ K",
                     keyCode: UInt32(kVK_ANSI_K),
                     carbonModifiers: UInt32(optionKey | controlKey)),
    ]

    static func named(_ id: String) -> HotKeyOption {
        all.first { $0.id == id } ?? all[0]
    }
}

/// Registers a system-wide hotkey via the Carbon hotkey API, which works
/// without extra permissions and fires even when the app is in the background.
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.onHotKey?() }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    func register(_ option: HotKeyOption) {
        unregister()
        let hotKeyID = EventHotKeyID(signature: OSType(0x4B54_5950), id: 1) // 'KTYP'
        RegisterEventHotKey(
            option.keyCode,
            option.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
