#!/bin/bash
. "$(dirname "$0")/resolve-path.sh"
exec infracost mcp "$@"
