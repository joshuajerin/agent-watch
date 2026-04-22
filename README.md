# Agent Watch

A standalone Apple Watch app that sends voice queries to your own VPS AI agent and streams responses back — entirely voice-driven, terminal-style display. No third-party AI cloud services are contacted directly from the device.

```
[Crown press] → [On-device STT] → [WSS to your VPS] → [AI agent] → [Stream back] → [Watch TTS + display]
```

## Features

- **Voice-only input** — Digital Crown press-to-talk using native `SFSpeechRecognizer` (on-device, no audio leaves the Watch)
- **Any AI backend** — your VPS runs the inference; swap Anthropic, Ollama, OpenAI, or any model you like
- **Streaming responses** — tokens streamed over WebSocket, rendered word-by-word
- **Terminal-style UI** — monospace scrollable text, minimal chrome
- **Zero third-party Swift deps** — AVFoundation, Speech, Network, CryptoKit only
- **Keychain token storage** — bearer token never touches UserDefaults

## Quick Start

### 1. Deploy the VPS Server

```bash
cd agent-watch-server
cp .env.example .env
# Edit .env: set ANTHROPIC_API_KEY and AUTH_TOKEN
docker compose up -d
```

### 2. Build & Install the Watch App

> **Requires:** Xcode 15+, macOS 14+, Apple Developer account, physical Apple Watch (watchOS 10+).
> See [docs/TESTFLIGHT_CHECKLIST.md](docs/TESTFLIGHT_CHECKLIST.md) for signing steps.

Open `AgentWatch/AgentWatch.xcodeproj` in Xcode, set your Team & Bundle ID, and run on your Watch.

### 3. Configure the App

In the Watch app → Settings:
- **VPS URL:** `wss://your-vps-ip:443/ws`
- **Auth Token:** the value of `AUTH_TOKEN` from your `.env`

### 4. Smoke Test the Server Before Pairing the Watch

```bash
cd agent-watch-server
cp .env.example .env  # if you have not created it yet
uvicorn main:app --host 127.0.0.1 --port 8000 --reload
curl http://127.0.0.1:8000/health
```

Expected health response shape:

```json
{"status":"ok","version":"1.0.0","provider":"anthropic","model":"claude-haiku-4-5-20251001","rate_limit_qpm":20}
```

That gives you a quick sanity check that config loading, model selection, and the local API process are all wired before testing on-device.

## Repository Layout

```
AgentWatch/          watchOS Xcode project (Swift, zero 3rd-party deps)
AgentWatchCore/      Swift Package with Linux-testable shared logic
agent-watch-server/  FastAPI VPS server (Python 3.12)
docs/                Architecture, API contract, checklists
scripts/             Token generator, cert-pinning helper
.github/workflows/   CI workflows (removed; see note below)
```

> **CI workflows:** The GitHub Actions workflows for Swift lint and Python tests have been removed due to push-token workflow scope limitations. You can re-add them after pushing with a GitHub token that has the `workflow` scope.

## Documentation

- [API Contract](docs/API_CONTRACT.md) — WebSocket & REST message schemas
- [Server Setup](docs/SERVER_SETUP.md) — nginx, TLS, Fail2ban, firewall
- [TestFlight Checklist](docs/TESTFLIGHT_CHECKLIST.md) — App Store submission steps
- [Security Review](SECURITY_REVIEW.md) — threat model, mitigations, hardening checklist
- [Build Status](docs/BUILD_STATUS.md) — CI results and known issues

## Development

```bash
# Run Python server tests
cd agent-watch-server && pip install -r requirements.txt && pytest

# Run Swift Package tests (Linux / macOS, no Xcode required)
cd AgentWatchCore && swift test

# Lint Python
cd agent-watch-server && ruff check . && mypy .
```

## License

MIT — personal use. See LICENSE.
