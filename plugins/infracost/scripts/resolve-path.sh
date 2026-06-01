# Source (don't execute) to augment PATH so `infracost` resolves under
# GUI-launched contexts where the inherited environment is minimal.

if [ -n "$SHELL" ] && [ -x "$SHELL" ]; then
  __LOGIN_PATH=$("$SHELL" -lc 'printf %s "$PATH"' 2>/dev/null)
  if [ -n "$__LOGIN_PATH" ]; then
    export PATH="$__LOGIN_PATH:$PATH"
  fi
  unset __LOGIN_PATH
fi

if ! command -v infracost >/dev/null 2>&1; then
  export PATH="$PATH:/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$HOME/bin"
fi
