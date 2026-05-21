#!/bin/bash

if ! command -v infracost &> /dev/null; then
  echo "Error: infracost CLI is not installed." >&2
  echo "Install it by following the instructions at https://www.infracost.io/docs/features/get_started/" >&2
  exit 1
fi

CMD=$(command -v infracost)
VERSION=$(infracost --version)
echo "infracost $VERSION found at $CMD"

# TODO(FIX-156): bump the minimum version once the MCP-enabled CLI is
# released. The plugin's .mcp.json runs `infracost mcp`, which requires
# the FIX-154 chain (currently in flight). The version this stamps to
# isn't released yet — pin it here when it lands.
MAJOR=$(echo "$VERSION" | grep -oE '[0-9]+' | head -1)
if [ -z "$MAJOR" ] || [ "$MAJOR" -lt 2 ]; then
  echo "Error: infracost v2.0.0 or newer is required (found $VERSION)." >&2
  echo "Upgrade by following the instructions at https://www.infracost.io/docs/features/get_started/" >&2
  exit 1
fi
