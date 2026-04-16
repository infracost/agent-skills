#!/bin/bash

if ! command -v infracost-preview &> /dev/null; then
  echo "Error: infracost-preview CLI is not installed." >&2
  echo "Install it by running /infracost:install" >&2
  exit 1
fi

CMD=$(command -v infracost-preview)
VERSION=$(infracost-preview --version)
echo "infracost-preview $VERSION found at $CMD"

if ! command -v infracost-ls &> /dev/null; then
  echo "Warning: infracost-ls language server is not installed." >&2
  echo "Install it by running /infracost:install-lsp" >&2
else
  LSP_CMD=$(command -v infracost-ls)
  LSP_VERSION=$(infracost-ls --version)
  echo "infracost-ls $LSP_VERSION found at $LSP_CMD"
fi
