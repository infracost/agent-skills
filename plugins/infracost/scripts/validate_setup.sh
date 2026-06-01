#!/bin/bash

. "$(dirname "$0")/resolve-path.sh"

if ! command -v infracost &> /dev/null; then
  echo "Error: infracost CLI is not installed." >&2
  echo "Install it by following the instructions at https://www.infracost.io/docs/features/get_started/" >&2
  exit 1
fi

CMD=$(command -v infracost)
VERSION=$(infracost --version)
echo "infracost $VERSION found at $CMD"

# The plugin's .mcp.json runs `infracost mcp`, which first shipped in
# infracost v2.2.0 (FIX-154). Require that as the floor.
SEMVER=$(echo "$VERSION" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
MAJOR=$(echo "$SEMVER" | cut -d. -f1)
MINOR=$(echo "$SEMVER" | cut -d. -f2)
if [ -z "$SEMVER" ] || [ "$MAJOR" -lt 2 ] || { [ "$MAJOR" -eq 2 ] && [ "$MINOR" -lt 2 ]; }; then
  echo "Error: infracost v2.2.0 or newer is required (found $VERSION)." >&2
  echo "Upgrade by following the instructions at https://www.infracost.io/docs/features/get_started/" >&2
  exit 1
fi
