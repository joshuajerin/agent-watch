# OpenClaw Integration Guide — Agent Watch

This guide tells the OpenClaw agent how to set up the Agent Watch server so the Apple Watch app can connect to it.

## Overview

The Agent Watch server (`agent-watch-server/`) is a FastAPI WebSocket relay. The watch app connects via `wss://`, authenticates with a bearer token, sends voice-transcribed text queries, and receives streamed text chunks back. The server's only job is to authenticate the connection, forward the query to an AI backend, and stream the response tokens back.

**OpenClaw replaces the default Anthropic backend.** Instead of calling the Anthropic API, the server should forward queries to OpenClaw and stream its responses.

---

## Architecture

```
[Apple Watch]
    │
    │ wss://your-vps:443/ws
    ▼
[nginx (TLS termination)]
    │
    │ http://127.0.0.1:8000/ws
    ▼
[agent-watch-server (FastAPI)]
    │
    │ Forward query text, stream back chunks
    ▼
[OpenClaw agent]
```

---

## WebSocket Protocol

The watch app speaks this exact protocol. The server must implement it.

### Connection Flow

1. Watch opens `wss://host/ws`
2. Watch sends: `{"type": "auth", "token": "<bearer-token>"}`
3. Server responds: `{"type": "auth_ok"}`
4. Watch sends: `{"type": "query", "text": "user's question", "session_id": "<uuid>"}`
5. Server streams back: `{"type": "chunk", "text": "partial", "session_id": "<uuid>"}` (one per token)
6. Server sends: `{"type": "done", "session_id": "<uuid>"}` when complete
7. On error: `{"type": "error", "code": 500, "message": "description"}`
8. Watch can send: `{"type": "cancel", "session_id": "<uuid>"}` to abort

### Constraints
- Max query text: 4096 chars
- Max response tokens: 2048 (configurable)
- WebSocket idle timeout: 60s
- Rate limit: 20 queries/min/token (configurable)

---

## What OpenClaw Needs to Do

### Option A: Replace the agent runner (recommended)

Edit `agent-watch-server/agent/runner.py` to call OpenClaw instead of Anthropic:

```python
async def run_agent(query: str) -> AsyncGenerator[str, None]:
    """Stream response chunks from OpenClaw."""
    # Connect to OpenClaw however it exposes its API
    # (HTTP streaming, WebSocket, subprocess, SDK, etc.)
    # and yield text chunks as they arrive.
    #
    # Example if OpenClaw has an HTTP streaming endpoint:
    async with httpx.AsyncClient() as client:
        async with client.stream("POST", "http://localhost:OPENCLAW_PORT/query",
                                  json={"text": query}) as resp:
            async for line in resp.aiter_lines():
                if line:
                    yield line
```

The rest of the server (auth, WebSocket handling, rate limiting) stays unchanged.

### Option B: Standalone WebSocket server

If OpenClaw wants to serve the WebSocket directly without the FastAPI relay, it must implement:

1. **`wss://host/ws` endpoint** accepting WebSocket connections
2. **Auth handshake**: first message is `{"type": "auth", "token": "..."}`, respond with `{"type": "auth_ok"}` or close with code `4001`
3. **Query handling**: receive `{"type": "query", "text": "...", "session_id": "..."}`, stream back `chunk` messages, end with `done`
4. **Cancel support**: receive `{"type": "cancel", "session_id": "..."}`, stop streaming for that session
5. **TLS via nginx** (or handle TLS directly) — the watch app ONLY connects to `wss://`, never `ws://`

---

## Server Setup Steps

### 1. Install & configure

```bash
cd agent-watch-server
cp .env.example .env
chmod 600 .env
```

Edit `.env`:
```env
AUTH_TOKEN=<generate-a-secure-random-token>
AI_PROVIDER=openclaw
LOG_LEVEL=INFO
```

Generate a token:
```bash
python3 ../scripts/gen_token.py
```

### 2. Modify runner.py for OpenClaw

Add an OpenClaw provider in `agent/runner.py`:

```python
async def run_agent(query: str) -> AsyncGenerator[str, None]:
    provider = settings.ai_provider.lower()
    if provider == "anthropic":
        async for chunk in _run_anthropic(query):
            yield chunk
    elif provider == "openclaw":
        async for chunk in _run_openclaw(query):
            yield chunk
    else:
        raise ValueError(f"Unknown AI provider: {provider}")


async def _run_openclaw(query: str) -> AsyncGenerator[str, None]:
    # TODO: Implement OpenClaw integration
    # This function must be an async generator that yields text strings
    # Each yield becomes one {"type": "chunk"} message to the watch
    raise NotImplementedError("Wire up OpenClaw here")
```

### 3. TLS + nginx

The watch requires `wss://` (TLS). Set up nginx as a reverse proxy:

```bash
# Install certbot
apt install certbot python3-certbot-nginx
certbot --nginx -d your-domain.com
```

nginx config (`/etc/nginx/sites-available/agent-watch`):
```nginx
server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/letsencrypt/live/your-domain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/your-domain.com/privkey.pem;
    ssl_protocols TLSv1.3;

    location /ws {
        proxy_pass http://127.0.0.1:8000/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_read_timeout 120s;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
    }
}
```

### 4. Run

```bash
docker compose up -d
# or without Docker:
pip install -r requirements.txt
uvicorn main:app --host 127.0.0.1 --port 8000
```

### 5. Verify

```bash
# Health check
curl https://your-domain.com/health
# Expected: {"status":"ok","version":"1.0.0"}

# WebSocket test (requires wscat: npm i -g wscat)
wscat -c wss://your-domain.com/ws
> {"type":"auth","token":"your-auth-token"}
< {"type":"auth_ok"}
> {"type":"query","text":"hello","session_id":"test-123"}
< {"type":"chunk","text":"Hello","session_id":"test-123"}
< {"type":"done","session_id":"test-123"}
```

---

## Watch App Configuration

Once the server is running, configure the watch app:

1. Open Agent Watch on the Apple Watch
2. Go to **Settings**
3. Set **VPS URL**: `wss://your-domain.com/ws`
4. Set **Auth Token**: the same `AUTH_TOKEN` value from `.env`
5. Tap **Save**

---

## Key Files

| File | Purpose |
|------|---------|
| `agent-watch-server/agent/runner.py` | **This is what OpenClaw modifies** — the AI backend integration |
| `agent-watch-server/routers/ws.py` | WebSocket handler (auth, query routing, cancel, rate limit) |
| `agent-watch-server/routers/api.py` | REST fallback endpoint (`POST /v1/query`) |
| `agent-watch-server/auth/bearer.py` | Token verification (constant-time comparison) |
| `agent-watch-server/config.py` | Environment config via pydantic-settings |
| `agent-watch-server/.env.example` | Template for `.env` |
