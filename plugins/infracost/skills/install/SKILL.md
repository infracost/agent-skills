---
description: Install or update the Infracost CLI. Use this skill when the user asks to install, update, or upgrade Infracost, or when the CLI is missing from the system.
allowed-tools: Bash
---

# Install Infracost CLI

Download and install the latest Infracost CLI binary from GitHub releases (`infracost/cli`).

The binary is called `infracost-preview`.

## Step 1: Check Current Version

If `infracost-preview` is already on the PATH, check the installed version:

```bash
infracost-preview --version
```

If the command is not found, proceed to step 2.

## Step 2: Look Up Latest Release

Query the latest release tag from `infracost/cli`. **Important**: The repository also contains plugin releases tagged like `infracost-parser-plugin/v0.1.0` or `infracost-provider-plugin-aws/v0.1.0` — these must be ignored. Only consider releases with tags matching `v*` (a plain version tag).

**Using `gh` (preferred):**

```bash
gh release list --repo infracost/cli --limit 20 --json tagName --jq '[.[] | select(.tagName | test("^v[0-9]"))][0].tagName'
```

**Fallback using `curl`:**

```bash
curl -sL \
  https://api.github.com/repos/infracost/cli/releases?per_page=20 \
  | grep '"tag_name"' | sed 's/.*"tag_name": *"//;s/".*//' | grep '^v[0-9]' | head -1
```

The tag format is `v2.0.0`. Derive the version number by stripping the `v` prefix (e.g., `2.0.0`).

## Step 3: Compare Versions

If `infracost-preview` is already installed and the installed version matches the latest version, inform the user that it is already up to date and stop.

## Step 4: Detect OS and Architecture

```bash
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64|arm64) ARCH="arm64" ;;
esac
```

On Windows (where `uname` may not be available or returns `MINGW`/`MSYS`/`CYGWIN`), set `OS=windows`. You can also detect Windows via the `OS` environment variable (`$env:OS -eq "Windows_NT"` in PowerShell).

Construct the asset filename:
- **Linux/macOS**: `infracost-preview_${VERSION}_${OS}_${ARCH}.tar.gz`
- **Windows**: `infracost-preview_${VERSION}_windows_${ARCH}.zip`

For example: `infracost-preview_2.0.0_darwin_arm64.tar.gz` or `infracost-preview_2.0.0_windows_amd64.zip`

## Step 5: Download

Download the release asset to a temporary directory (`/tmp` on Linux/macOS, `$TEMP` on Windows).

Determine the asset name using the filename constructed in step 4 (`.tar.gz` for Linux/macOS, `.zip` for Windows).

**Using `gh` (preferred):**

```bash
gh release download "$TAG" \
  --repo infracost/cli \
  --pattern "$ASSET_NAME" \
  --dir /tmp
```

**Fallback using `curl`:**

```bash
curl -sL \
  "https://github.com/infracost/cli/releases/download/${TAG}/${ASSET_NAME}" \
  -o "/tmp/${ASSET_NAME}"
```

## Step 6: Extract and Install

### Linux/macOS

```bash
tar -xzf "/tmp/${ASSET_NAME}" -C /tmp
chmod +x /tmp/infracost-preview
mv /tmp/infracost-preview /usr/local/bin/infracost-preview
```

If `mv` fails with a permission error, retry with `sudo`:

```bash
sudo mv /tmp/infracost-preview /usr/local/bin/infracost-preview
```

### Windows

```powershell
Expand-Archive -Path "$env:TEMP\$ASSET_NAME" -DestinationPath "$env:TEMP\infracost-preview" -Force
Move-Item -Path "$env:TEMP\infracost-preview\infracost-preview.exe" -Destination "$env:LOCALAPPDATA\Microsoft\WindowsApps\infracost-preview.exe" -Force
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
infracost-preview --version
```

The output should match the version that was just installed.

## Error Handling

- **Permission denied on `/usr/local/bin`**: Retry the `mv` with `sudo`. If that also fails, inform the user they need to grant write access or run with elevated privileges.
- **Unsupported platform**: If the OS is not `linux`, `darwin`, or `windows`, or the architecture is unsupported, inform the user and point them to the releases page at `https://github.com/infracost/cli/releases`.
- **Network errors**: If the download fails, check connectivity and retry once. If it fails again, inform the user.
