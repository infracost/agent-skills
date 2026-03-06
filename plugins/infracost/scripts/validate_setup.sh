#!/bin/bash

if ! command -v infracost-preview &> /dev/null; then
  echo "Error: infracost-preview CLI is not installed." >&2
  echo "Install it by running /infracost:install" >&2
  exit 1
fi

CMD=$(command -v infracost-preview)
VERSION=$(infracost-preview --version)
echo "infracost-preview $VERSION found at $CMD"
