"""WebSocket endpoint — primary communication channel for Watch app."""

import asyncio
import json
import logging
import uuid
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from typing import Any

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from agent.runner import run_agent
from auth.bearer import verify_token
from config import settings

logger = logging.getLogger(__name__)
router = APIRouter()

# Simple in-memory rate limiter: token -> list of request timestamps
_rate_windows: dict[str, list[datetime]] = defaultdict(list)


def _check_rate_limit(token: str) -> bool:
    """Return True if within rate limit, False if exceeded."""
    now = datetime.now(tz=timezone.utc)
    window = _rate_windows[token]
    # Remove entries older than 1 minute
    _rate_windows[token] = [t for t in window if now - t < timedelta(minutes=1)]
    if len(_rate_windows[token]) >= settings.rate_limit_qpm:
        return False
    _rate_windows[token].append(now)
    return True


def _safe_error(message: str) -> str:
    """Return a sanitized error JSON string — no stack traces."""
    return json.dumps({"type": "error", "code": 500, "message": message})


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()

    # Step 1: Auth handshake (first message must be auth)
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=10.0)
        msg: dict[str, Any] = json.loads(raw)
    except (asyncio.TimeoutError, json.JSONDecodeError):
        await websocket.close(code=4001)
        return

    if msg.get("type") != "auth" or not verify_token(msg.get("token", "")):
        logger.warning("AUTH_FAIL from %s", websocket.client)
        await websocket.close(code=4001)
        return

    token = msg["token"]
    await websocket.send_text(json.dumps({"type": "auth_ok"}))
    logger.info("WS authenticated: %s", websocket.client)

    # Step 2: Message loop
    active_tasks: dict[str, asyncio.Task] = {}

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await websocket.send_text(json.dumps({"type": "error", "code": 400, "message": "Invalid JSON"}))
                continue

            msg_type = msg.get("type")

            if msg_type == "query":
                text = msg.get("text", "").strip()
                session_id = msg.get("session_id", str(uuid.uuid4()))

                if len(text) > 4096:
                    await websocket.send_text(json.dumps({"type": "error", "code": 4003, "message": "Message too large"}))
                    continue

                if not _check_rate_limit(token):
                    await websocket.send_text(json.dumps({"type": "error", "code": 4002, "message": "Rate limit exceeded"}))
                    continue

                logger.debug("Query session=%s", session_id)  # text only at DEBUG

                async def stream_response(sid: str, query_text: str) -> None:
                    try:
                        async for chunk in run_agent(query_text):
                            await websocket.send_text(
                                json.dumps({"type": "chunk", "text": chunk, "session_id": sid})
                            )
                        await websocket.send_text(json.dumps({"type": "done", "session_id": sid}))
                    except asyncio.CancelledError:
                        pass
                    except Exception as exc:
                        logger.error("Agent error: %s", exc)
                        try:
                            await websocket.send_text(_safe_error("Agent error"))
                        except Exception:
                            pass

                task = asyncio.create_task(stream_response(session_id, text))
                active_tasks[session_id] = task

            elif msg_type == "cancel":
                session_id = msg.get("session_id", "")
                if task := active_tasks.pop(session_id, None):
                    task.cancel()
                    logger.debug("Cancelled session=%s", session_id)

    except WebSocketDisconnect:
        logger.info("WS disconnected: %s", websocket.client)
    finally:
        for task in active_tasks.values():
            task.cancel()
