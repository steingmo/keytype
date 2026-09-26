import SwiftUI

struct ContentView: View {
    @AppStorage("text") private var text = ""
    @AppStorage("speedIndex") private var speedIndex = 2
    @AppStorage("countdownSeconds") private var countdownSeconds = 3
    @AppStorage("textHotKey") private var textHotKey = HotKey.defaultText
    @AppStorage("hotKeyEnabled") private var hotKeyEnabled = false
    @AppStorage("clipboardHotKey") private var clipboardHotKey = HotKey.defaultClipboard
    @AppStorage("clipboardHotKeyEnabled") private var clipboardHotKeyEnabled = false

    @State private var recording: String? // which shortcut is being recorded
    @State private var secondsRemaining: Int?
    @State private var isTyping = false
    @State private var hasPermission = Typer.hasAccessibilityPermission

    private let background = Color(red: 0.10, green: 0.08, blue: 0.07)

    private var speed: TypingSpeed { TypingSpeed(rawValue: speedIndex) ?? .fast }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            editor

            settingRow(
                title: "Typing speed",
                caption: "Slow down for terminals or fields that lag."
            ) {
                CapsuleSlider(
                    fraction: Binding(
                        get: { Double(speedIndex) / 2 },
                        set: { speedIndex = Int(($0 * 2).rounded()) }
                    ),
                    label: speed.label
                )
            }

            settingRow(
                title: "Countdown",
                caption: "Time to click your target field before typing."
            ) {
                CapsuleSlider(
                    fraction: Binding(
                        get: { Double(countdownSeconds) / 10 },
                        set: { countdownSeconds = Int(($0 * 10).rounded()) }
                    ),
                    label: "\(countdownSeconds)s"
                )
            }

            Divider()

            settingRow(
                title: "Type text hotkey",
                caption: "Types the text above into the focused field in any app."
            ) {
                hotKeyControl($textHotKey, enabled: $hotKeyEnabled, id: "text")
            }

            settingRow(
                title: "Type clipboard hotkey",
                caption: "Copy anything with ⌘C, then press this to type it out."
            ) {
                hotKeyControl($clipboardHotKey, enabled: $clipboardHotKeyEnabled, id: "clipboard")
            }

            if !hasPermission {
                permissionBanner
            }

            typeButton
        }
        .padding(24)
        .background(background)
        .onAppear(perform: configureHotKeys)
        .onChange(of: hotKeyEnabled) { _ in configureHotKeys() }
        .onChange(of: textHotKey) { _ in configureHotKeys() }
        .onChange(of: clipboardHotKeyEnabled) { _ in configureHotKeys() }
        .onChange(of: clipboardHotKey) { _ in configureHotKeys() }
        .onChange(of: recording) { _ in configureHotKeys() }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            hasPermission = Typer.hasAccessibilityPermission
        }
    }

    // MARK: - Sections

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $text)
                .font(.system(size: 15, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
            if text.isEmpty {
                Text("Paste or type the text you want to send as keystrokes…")
                    .font(.system(size: 15, design: .monospaced))
                    .foregroundStyle(.secondary.opacity(0.6))
                    .padding(.horizontal, 15)
                    .padding(.vertical, 18)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 200)
        .background(Color.white.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func settingRow<Control: View>(
        title: String,
        caption: String,
        @ViewBuilder control: () -> Control
    ) -> some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(caption)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            control()
        }
    }

    private func hotKeyControl(_ hotKey: Binding<HotKey>, enabled: Binding<Bool>, id: String) -> some View {
        HStack(spacing: 10) {
            ShortcutRecorder(
                hotKey: hotKey,
                isRecording: Binding(get: { recording == id }, set: { recording = $0 ? id : nil })
            )
            Toggle("", isOn: enabled)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text("KeyType needs Accessibility access to send keystrokes.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Open Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                NSWorkspace.shared.open(url)
            }
            .font(.system(size: 12))
        }
        .padding(10)
        .background(Color.yellow.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var typeButton: some View {
        Button(action: startCountdown) {
            Text(buttonTitle)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .frame(height: 48)
        }
        .buttonStyle(.plain)
        .background(Color(red: 0.29, green: 0.46, blue: 0.96))
        .foregroundStyle(.white)
        .clipShape(Capsule())
        .disabled(text.isEmpty || isTyping || secondsRemaining != nil)
        .opacity(text.isEmpty ? 0.5 : 1)
    }

    private var buttonTitle: String {
        if isTyping { return "Typing…" }
        if let secondsRemaining { return "Typing in \(secondsRemaining)…" }
        if countdownSeconds == 0 { return "Type now" }
        return "Type now (\(countdownSeconds)s countdown)"
    }

    // MARK: - Actions

    private func configureHotKeys() {
        var bindings: [(HotKey, () -> Void)] = []
        // While recording, nothing is registered so the recorder sees the keys.
        // Hotkeys skip the countdown: the user is already in the target field.
        if recording == nil {
            if hotKeyEnabled {
                bindings.append((textHotKey, { typeText(text, after: 0.2, clearAfter: true) }))
            }
            if clipboardHotKeyEnabled {
                bindings.append((clipboardHotKey, typeClipboard))
            }
        }
        HotKeyManager.shared.set(bindings)
    }

    private func typeClipboard() {
        guard let clipboard = NSPasteboard.general.string(forType: .string), !clipboard.isEmpty else {
            NSSound.beep()
            return
        }
        typeText(clipboard, after: 0.2, clearAfter: false)
    }

    private func startCountdown() {
        guard !text.isEmpty else { return }
        Task { @MainActor in
            var remaining = countdownSeconds
            while remaining > 0 {
                secondsRemaining = remaining
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                remaining -= 1
            }
            secondsRemaining = nil
            typeText(text, after: 0, clearAfter: true)
        }
    }

    private func typeText(_ content: String, after delay: TimeInterval, clearAfter: Bool) {
        guard !content.isEmpty, !isTyping else { return }
        let typingSpeed = speed
        let keyMap = Typer.layoutKeyMap() // main thread; TIS APIs assert on it
        isTyping = true
        Task.detached {
            if delay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
            Typer.type(content, speed: typingSpeed, keyMap: keyMap)
            await MainActor.run {
                isTyping = false
                if clearAfter { text = "" }
            }
        }
    }
}

/// The pill-shaped slider from the mockup: filled track with the value
/// label sitting at the right edge.
struct CapsuleSlider: View {
    @Binding var fraction: Double
    let label: String

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.12))
                Capsule()
                    .fill(Color(red: 0.20, green: 0.24, blue: 0.40))
                    .frame(width: max(36, geo.size.width * fraction))
                HStack {
                    Spacer()
                    Text(label)
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.trailing, 16)
                }
            }
            .contentShape(Capsule())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        fraction = min(1, max(0, gesture.location.x / geo.size.width))
                    }
            )
        }
        .frame(width: 190, height: 42)
        .animation(.easeOut(duration: 0.1), value: fraction)
    }
}
