"""REST fallback endpoint — used when WebSocket is unavailable."""

import logging
import uuid

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from agent.runner import run_agent
from auth.bearer import verify_token

logger = logging.getLogger(__name__)
router = APIRouter()
security = HTTPBearer()


class QueryRequest(BaseModel):
    text: str = Field(..., max_length=4096)
    session_id: str = Field(default_factory=lambda: str(uuid.uuid4()))


class QueryResponse(BaseModel):
    session_id: str
    response: str
    finish_reason: str = "end_turn"


def _require_auth(creds: HTTPAuthorizationCredentials = Depends(security)) -> str:
    if not verify_token(creds.credentials):
        raise HTTPException(status_code=401, detail="Unauthorized")
    return creds.credentials


@router.post("/query", response_model=QueryResponse)
async def query(req: QueryRequest, _token: str = Depends(_require_auth)) -> QueryResponse:
    logger.debug("REST query session=%s", req.session_id)
    chunks: list[str] = []
    try:
        async for chunk in run_agent(req.text):
            chunks.append(chunk)
    except Exception as exc:
        logger.error("Agent error: %s", exc)
        raise HTTPException(status_code=503, detail="AI backend unavailable")
    return QueryResponse(session_id=req.session_id, response="".join(chunks))
