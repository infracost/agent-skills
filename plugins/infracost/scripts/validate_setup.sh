#!/bin/bash

if ! command -v infracost &> /dev/null; then
  echo "Error: infracost CLI is not installed." >&2
  echo "Install it from https://www.github.com/infracost/cli-poc/releases" >&2

  # TODO: Run install script to ensure CLI availability
  exit 1
fi

CMD=$(command -v infracost)
VERSION=$(infracost --version)
echo "infracost $VERSION found at $CMD"
