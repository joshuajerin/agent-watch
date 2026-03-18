# Agent Watch — Implementation Plan
**Date:** 2026-03-18
**Project:** Generic Apple Watch voice-only AI terminal app connected to user VPS
**Target:** TestFlight public beta

---

## 1. Vision & Scope

Agent Watch is a standalone Apple Watch app that lets users issue voice commands and receive AI-generated responses — all routed through the user's own VPS. No iPhone dependency for core functionality. No third-party AI cloud services are contacted directly from the device; all inference proxying happens server-side.

**Core loop:**
```
[User speaks] → [Watch STT] → [WebSocket/HTTPS to VPS] → [AI agent on VPS] → [Response streamed back] → [Watch TTS + display]
```

**Out of scope (v1):**
- iPhone companion app (optional pairing only)
- On-device ML inference
- Multi-user / shared VPS accounts
- Android / non-Apple wearables

---

## 2. Architecture

### 2.1 Client (watchOS)

```
AgentWatch.app (watchOS 10+)
├── Views/
│   ├── ContentView.swift          # Root: idle / listening / responding states
│   ├── SettingsView.swift         # VPS URL, auth token, voice config
│   └── HistoryView.swift          # Scrollable transcript (last 20 turns)
├── Audio/
│   ├── SpeechRecorder.swift       # AVAudioEngine + SFSpeechRecognizer
│   └── SpeechSynthesizer.swift    # AVSpeechSynthesizer wrapper
├── Network/
│   ├── VPSClient.swift            # URLSession WebSocket + REST fallback
│   └── StreamingParser.swift      # SSE / JSON-lines response chunker
├── State/
│   ├── AppState.swift             # ObservableObject: session, history, errors
│   └── ConversationStore.swift    # In-memory + WatchKit UserDefaults
└── AgentWatchApp.swift            # Entry point, lifecycle
```

**Dependency policy:** zero third-party Swift packages in v1. All functionality via Apple frameworks (AVFoundation, Speech, Network, CryptoKit).

### 2.2 Server (VPS)

```
agent-watch-server/
├── main.py                        # FastAPI app entrypoint
├── routers/
│   ├── ws.py                      # /ws WebSocket endpoint (primary)
│   └── api.py                     # /v1/query REST fallback
├── agent/
│   ├── runner.py                  # Anthropic SDK agent loop
│   └── tools.py                   # Optional shell / file tools for agent
├── auth/
│   └── bearer.py                  # Static token + optional TOTP
├── config.py                      # Pydantic settings from env
├── Dockerfile
└── requirements.txt
```

**Stack:** Python 3.12, FastAPI, Uvicorn, `anthropic` SDK, `python-dotenv`.

### 2.3 Communication Protocol

| Layer | Choice | Reason |
|---|---|---|
| Transport | WSS (TLS 1.3) | Low latency streaming; Watch supports URLSessionWebSocketTask |
| Auth | Bearer token in first WS message (not URL) | Avoids token in server logs |
| Message format | JSON-lines | Simple, streamable, no extra deps |
| Fallback | HTTPS POST `/v1/query` | When WS unavailable (cellular constraints) |
| STT | on-device `SFSpeechRecognizer` | Privacy; no audio leaves device |
| TTS | on-device `AVSpeechSynthesizer` | Same |

**WebSocket message schema:**

```jsonc
// Client → Server
{ "type": "auth",  "token": "..." }
{ "type": "query", "text": "...", "session_id": "uuid" }
{ "type": "cancel" }

// Server → Client
{ "type": "chunk",  "text": "...", "session_id": "uuid" }
{ "type": "done",   "session_id": "uuid" }
{ "type": "error",  "code": 4xx|5xx, "message": "..." }
```

---

## 3. Milestones

| # | Name | Target | Exit Criteria |
|---|---|---|---|
| M0 | Skeleton & CI | Week 1 | Xcode project builds; server runs locally; lint passes |
| M1 | Voice → Text | Week 2 | Watch records speech, transcribes on-device, displays text |
| M2 | Text → VPS → AI | Week 3 | Transcribed text reaches VPS, AI responds, text shown on Watch |
| M3 | Streaming responses | Week 4 | Chunked tokens render word-by-word on Watch face |
| M4 | TTS playback | Week 5 | AI response spoken aloud via Watch speaker |
| M5 | Settings & persistence | Week 6 | VPS URL + token persist across relaunches; history view works |
| M6 | Security hardening | Week 7 | Security review checklist complete; penetration test self-review |
| M7 | TestFlight beta | Week 8 | App passes App Store Review Guidelines check; submitted |

---

## 4. Feature-by-Feature Commit Plan

Each commit corresponds to a shippable, reviewable unit of work.

### M0 — Skeleton & CI

```
feat: initialize watchOS Xcode project with AgentWatch target
feat: add FastAPI server skeleton with /health endpoint
ci: add GitHub Actions workflow for Swift build + lint (SwiftLint)
ci: add Python lint + type-check (ruff, mypy) workflow
chore: add .gitignore for Xcode, Python, secrets
docs: add README with local dev setup instructions
```

### M1 — Voice → Text

```
feat(audio): implement SpeechRecorder with AVAudioEngine tap
feat(audio): wire SFSpeechRecognizer for on-device transcription
feat(ui): ContentView listening state with crown-press-to-talk trigger
feat(ui): display live transcription partial results
test: unit tests for SpeechRecorder state machine (idle/recording/done)
fix(audio): handle microphone permission denial gracefully
```

### M2 — Text → VPS → AI

```
feat(network): implement VPSClient with URLSessionWebSocketTask
feat(network): auth handshake — send bearer token on connect
feat(server): WebSocket endpoint /ws with auth validation
feat(server): agent/runner.py — forward query to Anthropic SDK, return response
feat(ui): show "thinking" spinner state while awaiting response
test(server): pytest for auth rejection on bad token
test(server): pytest for successful round-trip query→response
```

### M3 — Streaming Responses

```
feat(server): stream Anthropic SDK response chunks over WebSocket
feat(network): StreamingParser for JSON-lines chunk reassembly
feat(ui): word-by-word text rendering in ContentView response state
feat(network): implement cancel message — server aborts in-flight request
test: simulate slow stream, verify UI updates incrementally
```

### M4 — TTS Playback

```
feat(audio): SpeechSynthesizer wrapper around AVSpeechSynthesizer
feat(audio): enqueue chunks for playback as they arrive (overlap decode+speak)
feat(ui): visual waveform indicator during playback
feat(settings): voice rate / pitch controls in SettingsView
fix(audio): handle Watch audio session interruption (incoming call)
```

### M5 — Settings & Persistence

```
feat(settings): SettingsView — VPS URL, bearer token (stored in Keychain)
feat(settings): Keychain wrapper using Security framework
feat(state): ConversationStore — persist last 20 turns to UserDefaults
feat(ui): HistoryView with Digital Crown scroll
feat(ui): long-press utterance to copy/resend
fix(state): clear sensitive token on Sign Out action
```

### M6 — Security Hardening

```
security: enforce TLS certificate pinning for VPS connection
security: add TOTP second-factor option in server bearer.py
security: rate-limit WS connections per token (server-side)
security: sanitize server error messages — no stack traces to client
security: add request timeout (15 s) and max-response-size guard on Watch
audit: review all UserDefaults keys — move sensitive data to Keychain
docs: SECURITY.md threat model and responsible disclosure policy
```

### M7 — TestFlight Readiness

```
feat: add App Privacy manifest (PrivacyInfo.xcprivacy)
feat: add required usage description strings (microphone, speech)
fix: resolve any Xcode Organizer warnings
chore: bump version to 1.0.0 (build 1)
docs: TestFlight beta testing notes
ci: add archive + export workflow for Ad Hoc distribution
```

---

## 5. TestFlight Readiness Checklist

### App Store / TestFlight Requirements

- [ ] Bundle ID registered in App Store Connect
- [ ] watchOS deployment target set (watchOS 10.0 minimum)
- [ ] App icons provided for all required sizes (38mm–49mm Ultra)
- [ ] `NSMicrophoneUsageDescription` in Info.plist
- [ ] `NSSpeechRecognitionUsageDescription` in Info.plist
- [ ] `PrivacyInfo.xcprivacy` manifest listing: microphone access, on-device speech recognition
- [ ] No calls to private/restricted APIs (verify with `nm` scan)
- [ ] App does not require network entitlement beyond standard (no VPN/hotspot entitlements needed)
- [ ] Exported compliance: app uses standard HTTPS/WSS (no custom encryption requiring BIS)

### Functional Smoke Tests (manual, on physical hardware)

- [ ] Cold launch on Series 9 and Ultra 2 (minimum two device classes)
- [ ] Crown-press starts recording; release sends query
- [ ] Response streams and is spoken within 5 s on Wi-Fi
- [ ] Response streams and is spoken within 10 s on LTE
- [ ] App handles VPS unreachable: shows error, does not hang
- [ ] App handles mid-stream cancel: stops TTS, returns to idle
- [ ] Settings survive app restart (URL + token persisted)
- [ ] History view shows last 20 turns after relaunch
- [ ] Incoming call during TTS: audio ducks, resumes after call
- [ ] Low battery mode: app degrades gracefully (no background tasks)

### Automated Test Gate (CI must be green before submit)

- [ ] All Swift unit tests pass (`xcodebuild test`)
- [ ] All Python pytest tests pass
- [ ] SwiftLint: zero errors, zero warnings
- [ ] `ruff check` + `mypy`: clean
- [ ] No hardcoded secrets in repo (`git-secrets` or `trufflehog` scan)

---

## 6. Security Review

### 6.1 Threat Model

| Threat | Vector | Mitigation |
|---|---|---|
| Token theft | Token in URL query param | Token sent only in first WS message body, never in URL |
| MITM | Rogue Wi-Fi / LTE | TLS 1.3 + certificate pinning to user's VPS cert |
| Replay attack | Captured WS auth message | Server tracks last-seen nonce; token rotatable |
| Brute-force token | Automated WS connections | Server rate-limits by IP; exponential back-off lockout |
| Keychain exfiltration | Compromised device | Token stored with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| Server-side RCE | If agent has shell tools enabled | Tool execution sandboxed; disabled by default in v1 |
| Log leakage | Server logs containing query text | Queries logged only at DEBUG level; production log level INFO+ |
| Dependency supply chain | Python packages | `requirements.txt` pinned to exact hashes; renovate-bot for updates |

### 6.2 Authentication Flow

```
1. Watch opens WSS connection to wss://your-vps:443/ws
2. Watch sends: { "type": "auth", "token": "<bearer>" }
3. Server validates token (constant-time compare via `hmac.compare_digest`)
4. Server responds: { "type": "auth_ok" } or closes with 4001
5. All subsequent messages on this connection are trusted
6. Connection timeout: 60 s idle → server closes
```

### 6.3 Certificate Pinning Implementation

```swift
// VPSClient.swift
func urlSession(_ session: URLSession,
                didReceive challenge: URLAuthenticationChallenge,
                completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
    guard
        let serverTrust = challenge.protectionSpace.serverTrust,
        let cert = SecTrustGetCertificateAtIndex(serverTrust, 0),
        let pinnedHash = Bundle.main.object(forInfoDictionaryKey: "VPSCertSHA256") as? String,
        sha256(cert) == pinnedHash
    else {
        completionHandler(.cancelAuthenticationChallenge, nil)
        return
    }
    completionHandler(.useCredential, URLCredential(trust: serverTrust))
}
```

The VPS certificate's SHA-256 fingerprint is embedded in `Info.plist` at build time. Users who rotate their cert must rebuild the app (acceptable for personal-use beta).

### 6.4 Server Hardening Checklist

- [ ] VPS runs behind firewall; only ports 443 (WSS) and 22 (SSH) open
- [ ] Uvicorn bound to `127.0.0.1`; nginx reverse-proxy handles TLS termination
- [ ] nginx configured: `ssl_protocols TLSv1.3; ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384`
- [ ] `server_tokens off` in nginx config
- [ ] Fail2ban watching nginx access log for 4001 WS auth failures
- [ ] Server runs as non-root user `agent-watch` with minimal filesystem permissions
- [ ] `.env` file with `ANTHROPIC_API_KEY` has `chmod 600`; not committed to git
- [ ] Automated daily `apt upgrade` for security patches (unattended-upgrades)
- [ ] Periodic log rotation; logs do not contain query text at INFO level

### 6.5 Privacy Considerations

- All speech recognition is on-device (Apple's `SFSpeechRecognizer` in on-device mode).
- Audio is never transmitted; only the transcribed text string is sent to VPS.
- Conversation history stored only in Watch's encrypted UserDefaults (device-encrypted at rest).
- Server-side: queries may be logged at DEBUG; production deployments MUST set `LOG_LEVEL=INFO`.
- No analytics, no telemetry, no third-party SDKs on either client or server.

---

## 7. Directory Layout (Final)

```
agent-watch/
├── AgentWatch/                    # Xcode project root
│   ├── AgentWatch.xcodeproj
│   └── AgentWatch Watch App/      # watchOS target
│       ├── Assets.xcassets
│       ├── Info.plist
│       ├── PrivacyInfo.xcprivacy
│       ├── Views/
│       ├── Audio/
│       ├── Network/
│       └── State/
├── agent-watch-server/            # VPS Python server
│   ├── Dockerfile
│   ├── docker-compose.yml
│   ├── requirements.txt
│   ├── .env.example
│   └── src/
├── docs/
│   ├── plans/
│   │   └── 2026-03-18-agent-watch-implementation-plan.md
│   ├── SECURITY.md
│   └── SERVER_SETUP.md
├── scripts/
│   ├── gen_token.py               # Bearer token generator
│   └── pin_cert.sh                # Extract + embed cert fingerprint
├── .github/
│   └── workflows/
│       ├── ios.yml
│       └── server.yml
└── README.md
```

---

## 8. Open Questions / Decisions to Revisit

1. **Wake word vs. crown press** — Digital Crown press is the v1 trigger. Wake word (`Hey Watch`) would require always-on microphone and significant battery impact; defer to v2.
2. **Watch independence vs. iPhone relay** — v1 targets independent LTE Watch. If users have Wi-Fi-only Watches, an iPhone relay companion app may be needed; scope that as v1.5.
3. **Cert pinning UX for cert rotation** — Current plan requires app rebuild. Alternative: TOFU (Trust On First Use) with fingerprint stored in Keychain; evaluate before M6.
4. **Multi-turn context window** — Server currently passes full history per request. For long conversations, implement sliding window (last N turns) to avoid hitting model context limits.
5. **Offline / cached response mode** — Out of scope v1 but worth noting: Watch could cache last response for re-playback when VPS is unreachable.
