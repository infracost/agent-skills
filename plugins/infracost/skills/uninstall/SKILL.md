---
description: Uninstall the Infracost CLI. Use this skill when the user asks to uninstall or remove Infracost from their system.
allowed-tools: Bash
---

# Uninstall Infracost CLI

Remove the Infracost CLI binary from the system.

## Step 1: Locate the Binary

Find the installed `infracost-poc` binary:

```bash
command -v infracost-poc
```

If the command is not found, inform the user that Infracost is not installed and stop.

## Step 2: Check for Package Manager Installation

Resolve the real path of the binary (following symlinks) and check whether it appears to be managed by a package manager. Do **not** remove the binary if the resolved path is inside any of these directories:

### Linux/macOS

```bash
REAL_PATH=$(realpath "$(command -v infracost-poc)")
```

- `/opt/homebrew/` (Homebrew on Apple Silicon)
- `/usr/local/Cellar/` (Homebrew on Intel Mac)
- `/home/linuxbrew/` (Linuxbrew)
- `/usr/bin/` (system packages via apt, yum, dnf, etc.)
- `/snap/` (Snap packages)
- `/nix/store/` (Nix packages)

### Windows

```powershell
$resolvedPath = (Get-Command infracost-poc).Source | Resolve-Path
```

- `C:\ProgramData\chocolatey\` (Chocolatey)
- `C:\tools\` (Chocolatey alternative install location)
- `$env:LOCALAPPDATA\scoop\` (Scoop)
- `C:\Program Files\WinGet\` (WinGet/msstore)

If the resolved path falls inside any of these directories, inform the user that the binary appears to be managed by a package manager and they should use that package manager to uninstall it instead. **Stop and do not proceed.**

## Step 3: Remove the Binary

Delete the binary at the path returned by step 1.

### Linux/macOS

```bash
rm -f /path/to/infracost-poc
```

If `rm` fails with a permission error, retry with `sudo`:

```bash
sudo rm -f /path/to/infracost-poc
```

### Windows

```powershell
Remove-Item -Path (Get-Command infracost-poc).Source -Force
```

## Step 4: Verify

Confirm the binary has been removed:

```bash
command -v infracost-poc
```

The command should return nothing or report that `infracost-poc` is not found.

## Error Handling

- **Not installed**: If `command -v infracost-poc` returns nothing, inform the user that Infracost is not installed and stop.
- **Permission denied**: Retry the removal with `sudo`. If that also fails, inform the user they need to grant write access or run with elevated privileges.
