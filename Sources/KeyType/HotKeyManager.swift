import Carbon
import SwiftUI

/// A user-recorded global shortcut. Stored in @AppStorage as
/// "keyCode,carbonModifiers,label".
struct HotKey: RawRepresentable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon flags: cmdKey | optionKey | controlKey | shiftKey
    var label: String

    static let defaultText = HotKey(keyCode: UInt32(kVK_ANSI_X), modifiers: UInt32(optionKey | controlKey), label: "X")
    static let defaultClipboard = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(optionKey | controlKey), label: "V")

    init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }

    init?(rawValue: String) {
        let parts = rawValue.split(separator: ",", maxSplits: 2).map(String.init)
        guard parts.count == 3, let code = UInt32(parts[0]), let mods = UInt32(parts[1]) else { return nil }
        self.init(keyCode: code, modifiers: mods, label: parts[2])
    }

    var rawValue: String { "\(keyCode),\(modifiers),\(label)" }

    /// Needs ⌘, ⌃ or ⌥ — a plain or Shift-only key would hijack normal typing.
    init?(event: NSEvent) {
        let flags = event.modifierFlags
        guard !flags.isDisjoint(with: [.command, .control, .option]) else { return nil }
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        let chars = event.charactersIgnoringModifiers ?? ""
        let label: String
        if let scalar = chars.unicodeScalars.first, (0xF704...0xF726).contains(scalar.value) {
            label = "F\(scalar.value - 0xF703)" // NSF1FunctionKey…
        } else if event.keyCode == kVK_Space {
            label = "Space"
        } else {
            label = chars.uppercased()
        }
        self.init(keyCode: UInt32(event.keyCode), modifiers: UInt32(mods), label: label)
    }

    var display: String {
        var symbols = ""
        if modifiers & UInt32(controlKey) != 0 { symbols += "⌃ " }
        if modifiers & UInt32(optionKey) != 0 { symbols += "⌥ " }
        if modifiers & UInt32(shiftKey) != 0 { symbols += "⇧ " }
        if modifiers & UInt32(cmdKey) != 0 { symbols += "⌘ " }
        return symbols + label
    }
}

/// Click, then press the new shortcut. Esc cancels.
struct ShortcutRecorder: View {
    @Binding var hotKey: HotKey
    @Binding var isRecording: Bool
    @State private var monitor: Any?

    var body: some View {
        Button(isRecording ? "Press keys…" : hotKey.display) {
            isRecording ? stop() : start()
        }
        .frame(width: 110)
        .onDisappear(perform: stop)
    }

    private func start() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == kVK_Escape {
                stop()
            } else if let recorded = HotKey(event: event) {
                hotKey = recorded
                stop()
            }
            return nil // swallow keys while recording
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}

/// Registers system-wide hotkeys via the Carbon hotkey API, which works
/// without extra permissions and fires even when the app is in the background.
final class HotKeyManager {
    static let shared = HotKeyManager()

    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    private var eventHandlerRef: EventHandlerRef?

    private init() {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                    nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID
                )
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async { manager.actions[hotKeyID.id]?() }
                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    /// Replaces all registered hotkeys. A combo another app already owns
    /// (or a duplicate) silently fails to register.
    func set(_ bindings: [(HotKey, () -> Void)]) {
        refs.forEach { UnregisterEventHotKey($0) }
        refs = []
        actions = [:]
        for (index, (hotKey, action)) in bindings.enumerated() {
            let id = UInt32(index + 1)
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                hotKey.keyCode, hotKey.modifiers,
                EventHotKeyID(signature: OSType(0x4B54_5950), id: id), // 'KTYP'
                GetApplicationEventTarget(), 0, &ref
            )
            if status == noErr, let ref {
                refs.append(ref)
                actions[id] = action
            }
        }
    }
}
