"""Agent Watch Server — FastAPI entrypoint."""

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from config import settings
from routers.ws import router as ws_router
from routers.api import router as api_router

logging.basicConfig(level=getattr(logging, settings.log_level.upper(), logging.INFO))
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Agent Watch Server",
    version="1.0.0",
    docs_url=None,  # Disable Swagger UI in production
    redoc_url=None,
)

# CORS: only needed for REST fallback from browser dev tools
app.add_middleware(
    CORSMiddleware,
    allow_origins=[],  # No browser origin allowed; Watch app uses WSS directly
    allow_methods=["GET", "POST"],
    allow_headers=["Authorization", "Content-Type"],
)

app.include_router(ws_router)
app.include_router(api_router, prefix="/v1")


@app.get("/health")
async def health() -> dict:
    return {
        "status": "ok",
        "version": "1.0.0",
        "provider": settings.ai_provider,
        "model": settings.ai_model,
        "rate_limit_qpm": settings.rate_limit_qpm,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, log_level=settings.log_level.lower())
