---
description: Install or update the Infracost Language Server. Use this skill when the user asks to install the Infracost LSP, or when infracost-ls is missing from the system.
allowed-tools: Bash
---

# Install Infracost Language Server

Download and install the latest Infracost Language Server binary from GitHub releases (`infracost/lsp`).

The binary is called `infracost-ls`.

## Step 1: Check Current Version

If `infracost-ls` is already on the PATH, check the installed version:

```bash
infracost-ls --version
```

If the command is not found, proceed to step 2.

## Step 2: Look Up Latest Release

Query the latest release tag from `infracost/lsp`.

**Using `gh` (preferred):**

```bash
gh release view --repo infracost/lsp --json tagName --jq '.tagName'
```

**Fallback using `curl`:**

```bash
curl -sL \
  https://api.github.com/repos/infracost/lsp/releases/latest \
  | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//'
```

The tag format is `v0.0.3`. Derive the version number by stripping the `v` prefix (e.g., `0.0.3`).

## Step 3: Compare Versions

If `infracost-ls` is already installed and the installed version matches the latest version, inform the user that it is already up to date and stop.

## Step 4: Detect OS and Architecture

```bash
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac
```

On Windows (where `uname` may not be available or returns `MINGW`/`MSYS`/`CYGWIN`), set `OS=windows`.

Construct the asset filename:
- **Linux/macOS**: `lsp_${OS}_${ARCH}.tar.gz`
- **Windows**: `lsp_windows_${ARCH}.zip`

For example: `lsp_darwin_arm64.tar.gz` or `lsp_windows_amd64.zip`

## Step 5: Download

Download the release asset to a temporary directory (`/tmp` on Linux/macOS, `$TEMP` on Windows).

**Using `gh` (preferred):**

```bash
gh release download "$TAG" \
  --repo infracost/lsp \
  --pattern "$ASSET_NAME" \
  --dir /tmp
```

**Fallback using `curl`:**

```bash
curl -sL \
  "https://github.com/infracost/lsp/releases/download/${TAG}/${ASSET_NAME}" \
  -o "/tmp/${ASSET_NAME}"
```

## Step 6: Extract and Install

### Linux/macOS

```bash
tar -xzf "/tmp/${ASSET_NAME}" -C /tmp
chmod +x /tmp/infracost-ls
mv /tmp/infracost-ls /usr/local/bin/infracost-ls
```

If `mv` fails with a permission error, fall back to `~/.local/bin`:

```bash
mkdir -p ~/.local/bin
mv /tmp/infracost-ls ~/.local/bin/infracost-ls
```

If `~/.local/bin` is not already on the PATH, add it by appending to the user's shell profile:

```bash
# Detect the current shell profile
SHELL_NAME=$(basename "$SHELL")
case "$SHELL_NAME" in
  zsh)  PROFILE="$HOME/.zshrc" ;;
  bash) PROFILE="$HOME/.bashrc" ;;
  *)    PROFILE="$HOME/.profile" ;;
esac

echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$PROFILE"
export PATH="$HOME/.local/bin:$PATH"
```

Inform the user they may need to restart their shell or run `source <profile>` for the PATH change to take effect.

### Windows

```powershell
Expand-Archive -Path "$env:TEMP\$ASSET_NAME" -DestinationPath "$env:TEMP\infracost-ls" -Force
Move-Item -Path "$env:TEMP\infracost-ls\infracost-ls.exe" -Destination "$env:LOCALAPPDATA\Microsoft\WindowsApps\infracost-ls.exe" -Force
```

If `WindowsApps` is not on the PATH, move the binary to another directory that is on the PATH, or add the chosen directory to the PATH.

### Clean up

Remove the downloaded archive:

```bash
rm -f "/tmp/${ASSET_NAME}"
```

## Step 7: Verify

Confirm the installation succeeded:

```bash
infracost-ls --version
```

The output should match the version that was just installed.

## Error Handling

- **Permission denied on `/usr/local/bin`**: Fall back to `~/.local/bin` as described in Step 6. Do not use `sudo` as it may not be available in all environments.
- **Unsupported platform**: If the OS is not `linux`, `darwin`, or `windows`, or the architecture is unsupported, inform the user and point them to the releases page at `https://github.com/infracost/lsp/releases`.
- **Network errors**: If the download fails, check connectivity and retry once. If it fails again, inform the user.

## Troubleshooting

- **LSP fails to start or returns auth errors**: The LSP requires an API token that is obtained by logging in with the Infracost CLI. If the user hasn't logged in, the token won't exist and the LSP won't be able to run. Ask the user to run:
  ```bash
  infracost-preview login
  ```
  Then retry starting the LSP.
