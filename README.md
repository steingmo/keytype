# KeyType

A tiny native macOS app that "pastes" by typing — it sends your text as real
keystrokes, so it works in fields, terminals, VMs, and remote desktops that
block ⌘V.

## Install

With [Homebrew](https://brew.sh):

```sh
brew install --cask steingmo/tap/keytype
```

Or grab the latest notarized build from the
[Releases page](https://github.com/steingmo/keytype/releases), unzip, and drag
**KeyType.app** to Applications. The app is signed and notarized with a
Developer ID, so it runs without Gatekeeper warnings.

Requires macOS 13 (Ventura) or newer, Intel or Apple silicon. On first launch,
grant Accessibility permission when prompted — it's required for sending
keystrokes.

The app checks for updates via [Sparkle](https://sparkle-project.org)
(or on demand from the app menu) and can install them in place. Homebrew
installs can also update with `brew upgrade --cask keytype`.

## Build

```sh
./build.sh
open build/KeyType.app
```

Requires Xcode command line tools. The app is assembled into `build/KeyType.app`
and ad-hoc signed. To install, drag it into `/Applications`.

## First launch

macOS will ask for **Accessibility** permission (System Settings → Privacy &
Security → Accessibility). KeyType needs it to synthesize keystrokes — enable
the toggle for KeyType, then relaunch if needed.

## Usage

1. Paste or type your text into the box.
2. Pick a typing speed — use **Slow** for laggy terminals or remote sessions.
3. Hit **Type now**, then click the target field during the countdown.

Or use the global hotkeys — click a shortcut to record your own combo:

- **Type text** (default ⌃⌥X) types the text in the box where your cursor is.
- **Type clipboard** (default ⌃⌥V) types whatever you last copied with ⌘C —
  copy anywhere, click into the target field, press the shortcut.

Characters are sent as the real keys of your keyboard layout (Return and Tab
included), so remote sessions receive actual keystrokes.

### Remote Desktop (Windows App)

Symbols your Mac layout types with ⌥ (on Nordic layouts: `\ @ { } [ ] | £`)
come out wrong or missing in the Windows App's default **Scancode** keyboard
mode: it forwards ⌥ as Windows Alt, while Windows puts those symbols on other
keys behind AltGr. Switch the session to **Unicode Keyboard** mode in the
Windows App menu bar and every character arrives as typed.
