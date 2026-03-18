#!/usr/bin/env python3
"""Generate a cryptographically secure bearer token for Agent Watch auth."""

import secrets
import sys


def generate_token(length: int = 48) -> str:
    """Generate a URL-safe base64 token of the given byte length."""
    return secrets.token_urlsafe(length)


if __name__ == "__main__":
    length = int(sys.argv[1]) if len(sys.argv) > 1 else 48
    token = generate_token(length)
    print(token)
    print(f"\n# Add to your .env file:")
    print(f"AUTH_TOKEN={token}")
