# Security Review — Agent Watch v1.0

**Date:** 2026-03-18
**Reviewer:** joshuajerin (self-review; independent audit recommended before public release)
**Scope:** watchOS client + VPS FastAPI server

---

## 1. Threat Model

| # | Threat | Vector | Severity | Mitigation | Status |
|---|--------|--------|----------|------------|--------|
| T1 | Token theft via URL | Token in WS upgrade URL logged by proxies | High | Token sent in first WS message body, never in URL | ✅ Implemented |
| T2 | MITM / eavesdropping | Rogue Wi-Fi or LTE interception | High | TLS 1.3 + certificate pinning (SHA-256 in Info.plist) | ✅ Implemented |
| T3 | Token brute-force | Automated WS connections | High | Server rate-limits by IP; exponential backoff lockout via Fail2ban | ✅ Implemented |
| T4 | Replay attack | Captured auth message replayed | Medium | Server tracks used nonces per token; 60 s idle timeout | ✅ Implemented |
| T5 | Keychain exfiltration | Compromised/jailbroken device | Medium | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` attribute | ✅ Implemented |
| T6 | Log leakage | Server logs containing user queries | Medium | Queries logged only at DEBUG; production must use INFO+ | ✅ Config enforced |
| T7 | Server-side RCE | Agent shell tools enabled | High | Shell tools disabled by default; sandboxed execution when on | ✅ Default-off |
| T8 | Supply chain (Python) | Malicious package update | Medium | `requirements.txt` pinned to exact hashes | ✅ Pinned |
| T9 | Insecure WebSocket | ws:// instead of wss:// | High | Client enforces wss:// scheme; plain ws:// rejected at config validation | ✅ Validated |
| T10 | Memory disclosure | Stack traces in error responses | Low | Server sanitizes all error messages at INFO level | ✅ Implemented |

---

## 2. Authentication Flow

```
1. Watch opens WSS connection: wss://your-vps:443/ws
2. Watch sends (first message):  { "type": "auth", "token": "<bearer>" }
3. Server validates via hmac.compare_digest (constant-time, no timing oracle)
4. Server responds: { "type": "auth_ok" } or closes with code 4001
5. Subsequent messages on this connection are trusted for session lifetime
6. Idle timeout: 60 s → server closes connection
7. Token rotation: user updates .env + app Settings; old sessions expire naturally
```

---

## 3. Certificate Pinning

The VPS TLS certificate's SHA-256 fingerprint is embedded in `Info.plist` as `VPSCertSHA256`.

```swift
// VPSClient.swift — urlSession(_:didReceive:completionHandler:)
// Pins to the leaf certificate. User must rebuild after cert rotation.
// Alternative (TOFU): defer to v1.5 per open question #3 in the plan.
```

**Rotation procedure:**
1. Obtain new cert fingerprint: `scripts/pin_cert.sh your-vps.example.com`
2. Update `Info.plist` → `VPSCertSHA256`
3. Increment build number, rebuild, redistribute via TestFlight

---

## 4. Data at Rest

| Data | Storage | Encryption |
|------|---------|------------|
| Bearer token | Keychain (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`) | iOS/watchOS hardware-encrypted |
| Conversation history (last 20 turns) | UserDefaults (Watch) | watchOS device encryption (Data Protection) |
| VPS URL | UserDefaults | watchOS device encryption |
| Audio | Never stored | Audio captured in memory only; released after STT |

---

## 5. Data in Transit

- Transport: WSS (TLS 1.3 enforced by server nginx config)
- Payload: JSON-lines, no binary blobs
- Audio: **never transmitted** — only STT-transcribed text strings are sent to VPS
- Response text: streamed as UTF-8 JSON chunks

---

## 6. Server Hardening Checklist

- [ ] Firewall: only ports 443 and 22 open
- [ ] Uvicorn bound to `127.0.0.1`; nginx handles TLS termination
- [ ] nginx: `ssl_protocols TLSv1.3; ssl_ciphers ECDHE-ECDSA-AES256-GCM-SHA384`
- [ ] `server_tokens off` in nginx
- [ ] Fail2ban: watches nginx log for 4001 WS auth failures (3 strikes → 1 h ban)
- [ ] Server runs as non-root user `agent-watch`
- [ ] `.env` file: `chmod 600`; not committed to git
- [ ] Unattended-upgrades enabled for daily security patches
- [ ] Log rotation: 7-day retention; no query text at INFO level

---

## 7. Privacy

- Speech recognition: on-device `SFSpeechRecognizer` (Apple on-device mode). Audio never leaves the Watch.
- Transcribed text is transmitted to **the user's own VPS only** — no Anthropic/OpenAI direct contact from device.
- No analytics, no crash reporting SDK, no telemetry of any kind.
- App Privacy manifest (`PrivacyInfo.xcprivacy`) declares: microphone access, on-device speech recognition.

---

## 8. Open Security Items (pre-public-release)

1. **Independent audit** — self-review only; recommend third-party before wide distribution.
2. **TOFU cert pinning** — current rebuild-required rotation is acceptable for personal beta; evaluate Trust On First Use for v1.5.
3. **TOTP second factor** — implemented in server `auth/bearer.py` but disabled by default; document activation steps.
4. **Penetration test** — run `nmap`, `wss-fuzzer`, and authenticated request fuzzing against staging VPS before TestFlight.
5. **Dependency audit** — run `pip-audit` and `safety check` on `requirements.txt` monthly.
