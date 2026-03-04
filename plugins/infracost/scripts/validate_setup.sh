#!/bin/bash

if ! command -v infracost-poc &> /dev/null; then
  echo "Error: infracost-poc CLI is not installed." >&2
  echo "Install it by running /infracost:install" >&2
  exit 1
fi

CMD=$(command -v infracost-poc)
VERSION=$(infracost-poc --version)
echo "infracost-poc $VERSION found at $CMD"
