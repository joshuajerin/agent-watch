"""Bearer token authentication — constant-time comparison to prevent timing attacks."""

import hmac
import logging

from config import settings

logger = logging.getLogger(__name__)


def verify_token(token: str) -> bool:
    """Constant-time token comparison. Returns True if valid."""
    if not settings.auth_token:
        logger.error("AUTH_TOKEN not configured — all connections rejected")
        return False
    if not token:
        return False
    # hmac.compare_digest prevents timing oracle attacks
    return hmac.compare_digest(token.encode(), settings.auth_token.encode())
