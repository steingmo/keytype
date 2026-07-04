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
    static func type(_ text: String, speed: TypingSpeed) {
        let source = CGEventSource(stateID: .combinedSessionState)

        for character in text {
            switch character {
            case "\n", "\r", "\r\n":
                postKey(CGKeyCode(kVK_Return), source: source)
            case "\t":
                postKey(CGKeyCode(kVK_Tab), source: source)
            default:
                postUnicode(character, source: source)
            }
            usleep(speed.interKeyDelay)
        }
    }

    private static func postKey(_ keyCode: CGKeyCode, source: CGEventSource?) {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
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
