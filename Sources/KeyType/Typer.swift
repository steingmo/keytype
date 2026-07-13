import CoreGraphics
import Carbon.HIToolbox
import Foundation

enum TypingSpeed: Int, CaseIterable {
    case slow = 0
    case medium = 1
    case fast = 2

    var label: String {
        switch self {
        case .slow: return "Slow"
        case .medium: return "Medium"
        case .fast: return "Fast"
        }
    }

    /// Delay between characters, in microseconds.
    var interKeyDelay: UInt32 {
        switch self {
        case .slow: return 60_000
        case .medium: return 25_000
        case .fast: return 5_000
        }
    }
}

enum Typer {
    /// Synthesizes the text as real HID keystrokes, character by character.
    /// Newlines and tabs are sent as their actual keys so terminals and
    /// forms behave naturally; everything else goes out as a unicode
    /// keyboard event, so any character works regardless of keyboard layout.
    typealias KeyMap = [Character: (CGKeyCode, CGEventFlags)]

    /// `keyMap` comes from `layoutKeyMap()`, which must be called on the
    /// main thread (the TIS APIs assert on it); typing itself can then run
    /// on any thread.
    static func type(_ text: String, speed: TypingSpeed, keyMap: KeyMap) {
        let source = CGEventSource(stateID: .combinedSessionState)

        // Physically-held modifiers (e.g. ⌥⌃ from the hotkey) merge into
        // synthesized keystrokes and corrupt them — wait for release first.
        waitForModifiersReleased()

        for character in text {
            switch character {
            case "\n", "\r", "\r\n":
                postKey(CGKeyCode(kVK_Return), source: source)
            case "\t":
                postKey(CGKeyCode(kVK_Tab), source: source)
            default:
                if let (keyCode, flags) = keyMap[character] {
                    postKey(keyCode, flags: flags, source: source)
                } else {
                    postUnicode(character, source: source)
                }
            }
            usleep(speed.interKeyDelay)
        }
    }

    /// Maps each character the current keyboard layout can produce with a
    /// single keypress to its key code + modifiers. Real key codes matter
    /// for RDP/VNC/VMs, which forward the key code and ignore the unicode
    /// payload (virtualKey 0 arrives as "a"). Dead keys are skipped (they
    /// need a second keystroke and would misfire locally).
    /// Main thread only — the TIS APIs dispatch-assert on it.
    static func layoutKeyMap() -> KeyMap {
        var map: KeyMap = [:]
        guard let source = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutPointer = TISGetInputSourceProperty(source, kTISPropertyUnicodeKeyLayoutData) else {
            return map
        }
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutPointer).takeUnretainedValue() as Data
        // Plain keys first so e.g. "a" maps to the unshifted key.
        let modifierSets: [(UInt32, CGEventFlags)] = [
            (0, []),
            (UInt32(shiftKey >> 8), .maskShift),
            (UInt32(optionKey >> 8), .maskAlternate),
            (UInt32((shiftKey | optionKey) >> 8), [.maskShift, .maskAlternate]),
        ]
        layoutData.withUnsafeBytes { (raw: UnsafeRawBufferPointer) in
            guard let layout = raw.bindMemory(to: UCKeyboardLayout.self).baseAddress else { return }
            for (modifierBits, flags) in modifierSets {
                for keyCode: UInt16 in 0..<128 {
                    var deadKeyState: UInt32 = 0
                    var length = 0
                    var chars = [UniChar](repeating: 0, count: 4)
                    let status = UCKeyTranslate(
                        layout, keyCode, UInt16(kUCKeyActionDown), modifierBits,
                        UInt32(LMGetKbdType()), 0, &deadKeyState,
                        chars.count, &length, &chars
                    )
                    guard status == noErr, deadKeyState == 0, length == 1,
                          let scalar = Unicode.Scalar(chars[0]) else { continue }
                    let character = Character(scalar)
                    if map[character] == nil {
                        map[character] = (CGKeyCode(keyCode), flags)
                    }
                }
            }
        }
        return map
    }

    private static func waitForModifiersReleased() {
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        for _ in 0..<40 { // give up after ~2 s
            if CGEventSource.flagsState(.combinedSessionState).intersection(modifiers).isEmpty {
                return
            }
            usleep(50_000)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, flags: CGEventFlags = [], source: CGEventSource?) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        down.flags = flags
        up.flags = flags
        down.post(tap: .cghidEventTap)
        usleep(1_000)
        up.post(tap: .cghidEventTap)
    }

    private static func postUnicode(_ character: Character, source: CGEventSource?) {
        let units = Array(String(character).utf16)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else { return }
        units.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        down.post(tap: .cghidEventTap)
        usleep(1_000)
        up.post(tap: .cghidEventTap)
    }

    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }
}
