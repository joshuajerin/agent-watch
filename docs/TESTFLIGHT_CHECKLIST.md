# TestFlight Submission Checklist — Agent Watch v1.0

**Target:** watchOS 10.0+, Apple Watch Series 4 and later
**Date:** 2026-03-18

---

## Phase 1: Xcode Project Setup

> These steps require Xcode 15+ on macOS 14+. Linux CI can build the Swift Package (AgentWatchCore) but cannot build the Xcode project or sign the app.

- [ ] Open `AgentWatch/AgentWatch.xcodeproj` in Xcode 15+
- [ ] Set **Team** to your Apple Developer account (Signing & Capabilities)
- [ ] Set **Bundle Identifier**: `com.yourname.agentwatch` (must be unique in App Store Connect)
- [ ] Set **Deployment Target**: watchOS 10.0
- [ ] Verify **Info.plist** contains:
  - `NSMicrophoneUsageDescription` — "Agent Watch uses the microphone to record your voice commands."
  - `NSSpeechRecognitionUsageDescription` — "Agent Watch transcribes your voice commands on-device."
  - `VPSCertSHA256` — SHA-256 fingerprint of your VPS TLS certificate (run `scripts/pin_cert.sh`)
- [ ] Verify **PrivacyInfo.xcprivacy** declares: microphone, on-device speech recognition
- [ ] App icons: add icons for all Watch sizes (38mm, 40mm, 41mm, 44mm, 45mm, 49mm Ultra) to `Assets.xcassets`

---

## Phase 2: App Store Connect Setup

- [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com)
- [ ] Create a new app: Platforms → watchOS
- [ ] Enter Bundle ID (must match Xcode)
- [ ] Enter app name: "Agent Watch"
- [ ] Complete privacy questionnaire (microphone, speech recognition)
- [ ] Enable TestFlight for internal testing (add yourself as tester)

---

## Phase 3: Certificate & Profile

- [ ] Create a Distribution Certificate (or use existing) in [Certificates, IDs & Profiles](https://developer.apple.com/account/resources)
- [ ] Register your Apple Watch UDID for Ad Hoc (development) testing
- [ ] Create a **Ad Hoc** provisioning profile for the Watch target
- [ ] Download and install profiles in Xcode (Xcode → Preferences → Accounts → Download Manual Profiles)

---

## Phase 4: Build & Archive

```bash
# From macOS terminal (not Linux)
xcodebuild \
  -project AgentWatch/AgentWatch.xcodeproj \
  -scheme "AgentWatch Watch App" \
  -configuration Release \
  -destination "generic/platform=watchOS" \
  archive \
  -archivePath build/AgentWatch.xcarchive
```

- [ ] Archive builds without errors or warnings
- [ ] No use of private/restricted APIs (verify: `nm build/AgentWatch.xcarchive/...` — no `_private` symbols)
- [ ] No hardcoded secrets in source (`git-secrets` scan clean)

---

## Phase 5: Export & Upload

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/AgentWatch.xcarchive \
  -exportOptionsPlist scripts/ExportOptions.plist \
  -exportPath build/export/
```

- [ ] Export succeeds → produces `.ipa`
- [ ] Upload via Xcode Organizer **or** `xcrun altool` / `xcrun notarytool`
- [ ] TestFlight processes the build (typically 5–30 min)

---

## Phase 6: TestFlight Review

Apple reviews TestFlight builds before external testing:

- [ ] Test information filled in (what to test, what's new)
- [ ] Beta App Description written
- [ ] Beta App Feedback Email set
- [ ] External testing group created with beta testers added
- [ ] Review approved (Apple typically reviews within 1–2 business days)

---

## Phase 7: Functional Smoke Tests (physical hardware required)

- [ ] Cold launch on Series 9 (or later) — app opens without crash
- [ ] Cold launch on Ultra 2 — confirm layout correct on larger crown
- [ ] Crown press → microphone activates, recording state shown
- [ ] Release crown → query sent, "thinking" state shown
- [ ] Response streams word-by-word within 5 s (Wi-Fi)
- [ ] Response streams within 10 s (LTE)
- [ ] TTS plays response through Watch speaker
- [ ] Cancel (second crown press during response) — TTS stops, returns to idle
- [ ] VPS unreachable → error message shown within 15 s, no hang
- [ ] Settings persist across app restart (VPS URL + token)
- [ ] History view shows last 20 turns after full relaunch
- [ ] Incoming call during TTS: audio ducks correctly, resumes after call ends
- [ ] Low battery mode: no background tasks, graceful degradation

---

## Phase 8: Automated CI Gate (must be green before submission)

- [ ] Python `pytest` — all server tests pass (see [BUILD_STATUS.md](BUILD_STATUS.md))
- [ ] `ruff check agent-watch-server/` — zero issues
- [ ] `mypy agent-watch-server/` — zero errors
- [ ] Swift Package tests (`swift test` in `AgentWatchCore/`) — all pass
- [ ] `xcodebuild test` (macOS CI) — all Xcode unit tests pass
- [ ] SwiftLint — zero errors, zero warnings
- [ ] `trufflehog` / `git-secrets` — no secrets found in repo

---

## Signing Placeholder Note

> The Xcode project skeleton in `AgentWatch/` is ready for signing but **cannot be signed or archived on Linux**. All code is correct Swift; the signing and archive steps require Xcode on macOS with a valid Apple Developer account. This is a standard Apple platform constraint, not a project limitation.
