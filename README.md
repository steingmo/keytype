# KeyType

A tiny native macOS app that "pastes" by typing — it sends your text as real
keystrokes, so it works in fields, terminals, VMs, and remote desktops that
block ⌘V.

## Download

**[Download the latest KeyType.zip](https://github.com/steingmo/keytype/releases/latest)** —
unzip, drag `KeyType.app` to Applications, open. Signed and notarized; runs on
macOS 13+ (Intel and Apple Silicon). On first launch, grant Accessibility
permission when prompted — it's required for sending keystrokes.

## Build

```sh
./build.sh
open build/KeyType.app
```

Requires Xcode command line tools. The app is assembled into `build/KeyType.app`
and ad-hoc signed. To install, drag it into `/Applications`.

## Sharing with other Macs

`./release.sh` produces `build/KeyType.zip` — a universal (Intel + Apple
Silicon), Developer ID-signed, notarized build that opens on any Mac running
macOS 13+ with no Gatekeeper warnings.

One-time setup:

1. **Developer ID certificate** — in Xcode → Settings → Accounts → select your
   team → Manage Certificates → **+** → *Developer ID Application*. (Only the
   Account Holder role can create this certificate type.)
2. **Notary credentials** — create an app-specific password at
   [account.apple.com](https://account.apple.com) → Sign-In and Security →
   App-Specific Passwords, then store it:

   ```sh
   xcrun notarytool store-credentials keytype-notary \
     --apple-id you@example.com --team-id TEAMID --password xxxx-xxxx-xxxx-xxxx
   ```

   Your team ID is shown at developer.apple.com → Membership details.

Recipients still grant Accessibility permission on their own machine on first
launch.

## First launch

macOS will ask for **Accessibility** permission (System Settings → Privacy &
Security → Accessibility). KeyType needs it to synthesize keystrokes — enable
the toggle for KeyType, then relaunch if needed.

## Usage

1. Paste or type your text into the box.
2. Pick a typing speed — use **Slow** for laggy terminals or remote sessions.
3. Hit **Type now**, then click the target field during the countdown.

Or enable the **global hotkey** (default ⌥⌃X): focus the target field in any
app and press the hotkey — the stored text is typed right where your cursor
is, no countdown needed.

Newlines are sent as the Return key and tabs as the Tab key; everything else
(including emoji and non-ASCII characters) is sent as unicode key events, so
it works with any keyboard layout.
