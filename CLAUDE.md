# KeyType — project context

Tiny native macOS SwiftUI app that "pastes" by typing: it sends text as real
HID keystrokes, so it works in fields, terminals, VMs, and remote desktops
that block ⌘V. Requires macOS 13+, needs Accessibility permission. Fully
offline except Sparkle update checks. Distributed via GitHub Releases and a
Homebrew tap (`steingmo/homebrew-tap`, cask `keytype`).

## Architecture

Swift Package (no Xcode project), one dependency (Sparkle ≥ 2.6). All source
in `Sources/KeyType/`:

- `Typer.swift` — the core. Synthesizes keystrokes via `CGEvent` posted to
  `.cghidEventTap`. **Newlines/tabs are sent as real Return/Tab key codes**
  so terminals and forms behave naturally; every other character goes out as
  a unicode keyboard event (`keyboardSetUnicodeString`, virtualKey 0), which
  works for emoji/non-ASCII regardless of keyboard layout. `TypingSpeed`
  defines the three inter-key delays (60 ms / 25 ms / 5 ms). Also exposes
  `hasAccessibilityPermission` (`AXIsProcessTrusted`).
- `HotKeyManager.swift` — global hotkey via the **Carbon** hotkey API
  (`RegisterEventHotKey`), chosen deliberately because it needs no extra
  permissions and fires while the app is in the background. Fixed list of
  five `HotKeyOption` combos (default ⌥⌃X); handler bounces to main queue.
- `ContentView.swift` — the single window UI: text editor, speed +
  countdown `CapsuleSlider`s, hotkey picker/toggle, permission banner,
  "Type now" button. All settings persist via `@AppStorage`. The hotkey
  path types after a fixed 0.2 s delay (no countdown — the user is already
  focused on the target field); the button path counts down so the user can
  click the target. Text is cleared after a successful type. Permission
  state is re-polled on a 2 s timer so the banner clears once the user
  grants access.
- `KeyTypeApp.swift` — `@main`, fixed-width (460 pt) dark window,
  `AppDelegate` triggers the Accessibility prompt on first launch
  (`AXIsProcessTrustedWithOptions`), app quits when the window closes.
- `Updater.swift` — Sparkle `SPUStandardUpdaterController` wrapped in an
  `ObservableObject` + "Check for Updates…" menu command. Automatic checks
  are on (`SUEnableAutomaticChecks` in Info.plist).

`Info.plist` at the repo root is the source of truth for the version
(`CFBundleVersion`/`CFBundleShortVersionString`), the Sparkle feed URL
(`appcast.xml` served raw from `main`), and the Sparkle EdDSA public key.

`assets/make-icon.swift` renders the 1024×1024 icon PNG programmatically
(`swift assets/make-icon.swift <out.png>`); the committed `AppIcon.icns` is
derived from it. The iconset and PNG intermediates are gitignored.

## Building

- Dev: `swift build` (compile check) — `swift run` alone won't behave like
  the real app since Accessibility permission is tied to the signed bundle.
- App bundle: `./build.sh` — release build, assembles `build/KeyType.app` by
  hand (binary + Info.plist + icns), embeds Sparkle.framework from
  `.build/release/`, adds the `@executable_path/../Frameworks` rpath with
  `install_name_tool`, and **ad-hoc signs** (a stable signature keeps the
  Accessibility grant from being revoked on every rebuild). `build/` is
  gitignored.

## Releasing

Bump the version in `Info.plist` **first** — `release.sh` reads it, it does
not bump it. Then `./release.sh`:

1. Builds a universal binary (`--arch arm64 --arch x86_64`; output lands in
   `.build/apple/Products/Release/`).
2. Assembles and signs **in a temp dir under /tmp** — the project may live
   in an iCloud-synced folder whose file provider re-stamps xattrs that
   codesign rejects; never sign in place (`xattr -cr` before signing too).
3. Signs with hardened runtime + timestamp. Sparkle's nested helpers
   (Downloader.xpc — with `--preserve-metadata=entitlements` — Installer.xpc,
   Autoupdate, Updater.app, then the framework) must **each** be signed
   inside-out before the app itself.
4. Notarizes (`notarytool` keychain profile, default `keytype-notary`,
   override with `KEYTYPE_NOTARY_PROFILE`; identity via `KEYTYPE_IDENTITY`,
   default "Developer ID Application"), staples, and re-zips the stapled app
   to `build/KeyType.zip` (the zip name is versionless — the release tag
   carries the version).
5. Regenerates `appcast.xml` (single latest item only), signing the zip with
   Sparkle's `sign_update` from `.build/artifacts/` — it reads the EdDSA
   private key from the login keychain. **Never regenerate that key**:
   shipped apps only trust updates signed by the key matching
   `SUPublicEDKey` in Info.plist.

Publishing is **manual** after the script finishes (it prints the commands):
commit + push `appcast.xml` (that's the live Sparkle feed), then
`gh release create v<VERSION> build/KeyType.zip …`, then bump the Homebrew
cask via `bump-cask.sh keytype <VERSION>` in the tap repo.

Machine requirements for releasing (not needed for code changes): a
Developer ID certificate in the keychain, the `keytype-notary` notarytool
profile, the Sparkle EdDSA private key in the login keychain, an
authenticated `gh` CLI, and the Homebrew tap installed locally.

## Testing

No XCTest target. `swift build` is the compile check; behavior is verified
by running the built app (`./build.sh && open build/KeyType.app`). Actually
sending keystrokes requires the Accessibility grant, so `Typer` can't be
exercised headlessly — test typing manually against a target like TextEdit
or a terminal, including newline/tab and non-ASCII cases.

## Conventions / gotchas

- Keep the public repo free of personal identifiers (team IDs, Apple IDs,
  credential names beyond what the scripts already state).
- Accessibility permission is bound to the code signature: unsigned or
  re-signed builds may need the toggle flipped off/on again in System
  Settings → Privacy & Security → Accessibility.
- `appcast.xml` is committed and served raw from `main` — editing it on
  `main` immediately affects what shipped apps see.
- UI is compact and dark (`preferredColorScheme(.dark)`, fixed 460 pt
  width, capsule-shaped controls); match that style when adding controls.
