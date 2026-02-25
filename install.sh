#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

if [ $# -lt 1 ]; then
  echo "Usage: ./install.sh [skillName]"
  echo ""
  echo "Available skills:"
  ls "$TEMPLATES_DIR" | awk '{print "- "$1}'
  exit 1
fi

SKILL_NAME="$1"
TEMPLATE_DIR="$TEMPLATES_DIR/$SKILL_NAME"

if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: skill '$SKILL_NAME' not found in templates/"
  echo ""
  echo "Available skills:"
  ls "$TEMPLATES_DIR" | awk '{print "- "$1}'
  exit 1
fi

# Read the template
SKILL_CONTENT="$(cat "$TEMPLATE_DIR/SKILL.md")"

# Find all placeholders and prompt for values
PLACEHOLDERS="$(awk '{while(match($0, /\{\{[^}]+\}\}/)) {print substr($0, RSTART, RLENGTH); $0=substr($0, RSTART+RLENGTH)}}' "$TEMPLATE_DIR/SKILL.md" | sort -u || true)"

if [ -n "$PLACEHOLDERS" ]; then
  echo "This skill has placeholders that need values:"
  echo ""
  while IFS= read -r placeholder <&3; do
    inner="${placeholder#\{\{}"
    inner="${inner%\}\}}"
    name="${inner%%:*}"
    default="${inner#*:}"
    if [ "$default" = "$inner" ]; then
      default=""
    fi
    resolved=""
    if [ -n "$default" ]; then
      resolved="$(command -v "$default" 2>/dev/null || true)"
    fi
    if [ -n "$resolved" ]; then
      echo "  $name: found at $resolved"
      value="$resolved"
    elif [ -n "$default" ]; then
      read -rp "  $name [$default]: " value </dev/tty
      value="${value:-$default}"
    else
      read -rp "  $name: " value </dev/tty
    fi
    SKILL_CONTENT="${SKILL_CONTENT//"$placeholder"/$value}"
  done 3<<< "$PLACEHOLDERS"
  echo ""
fi

# Ask for install location
echo "Where do you want to install the skill?"
echo "  1) Global (~/.claude/skills) (default)"
echo "  2) Local (./.claude/skills)"
echo "  3) Custom path"
read -rp "Choice [1/2/3]: " location_choice </dev/tty

case "${location_choice:-1}" in
  1) DEST="$HOME/.claude/skills/$SKILL_NAME" ;;
  2) DEST="./.claude/skills/$SKILL_NAME" ;;
  3)
    read -rp "  Install path: " DEST </dev/tty
    if [ -z "$DEST" ]; then
      echo "Error: no path provided"
      exit 1
    fi
    ;;
  *)
    echo "Error: invalid choice"
    exit 1
    ;;
esac

if [ -f "$DEST/SKILL.md" ]; then
  read -rp "Skill already exists at $DEST. Overwrite? [y/N]: " overwrite </dev/tty
  if [ "$overwrite" != "y" ] && [ "$overwrite" != "Y" ]; then
    echo "Aborted."
    exit 0
  fi
fi

mkdir -p "$DEST"
echo "$SKILL_CONTENT" > "$DEST/SKILL.md"
echo "Installed $SKILL_NAME to $DEST/SKILL.md"
