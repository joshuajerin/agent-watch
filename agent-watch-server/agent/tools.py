"""Optional agent tools — disabled by default in v1 for security.

To enable shell tools, set ENABLE_TOOLS=true in .env and implement
the tool handler below. All tool execution should be sandboxed.
"""

import logging
import os

logger = logging.getLogger(__name__)

TOOLS_ENABLED = os.getenv("ENABLE_TOOLS", "false").lower() == "true"

# Tool definitions (passed to Anthropic API when enabled)
TOOL_DEFINITIONS: list[dict] = []

if TOOLS_ENABLED:
    logger.warning(
        "Agent tools are enabled. Ensure your VPS is properly sandboxed. "
        "Tool execution as the server user carries risk."
    )
    # Future: add tool definitions here (e.g., shell exec, file read)
    # TOOL_DEFINITIONS = [{ "name": "bash", ... }]
