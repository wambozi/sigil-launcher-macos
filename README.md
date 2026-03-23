# Sigil Launcher for macOS

Native macOS application that manages ephemeral NixOS virtual machine workspaces powered by the Sigil intelligence daemon. The launcher handles VM lifecycle, image building, hardware detection, and local LLM model management through a SwiftUI interface.

## Prerequisites

- macOS 13 (Ventura) or later
- Xcode 15+ with Swift 5.9+
- [Nix](https://nixos.org/download/) (required for building VM images)
- Apple Silicon (arm64) or Intel Mac (x86_64)
- Minimum 8 GB system RAM and 10 GB free disk space

## Quick Start

### Build

```bash
swift build
```

### Run

```bash
# Creates required directories and launches the app
make run
```

Or directly:

```bash
swift run SigilLauncher
```

### Test

```bash
swift test
```

### Release Build

```bash
swift build -c release
```

## Architecture

```
SigilLauncherApp (SwiftUI @main)
    |
    +-- SetupWizard -----> first-run configuration flow
    |                       |
    +-- LauncherView -----> main UI (start/stop VM, status)
    |                       |
    +-- ConfigurationView -> settings panel (Preferences)
    |
    +-- VMManager ----------> VM lifecycle orchestration
            |
            +-- VMConfiguration --> builds VZVirtualMachineConfiguration
            |
            +-- VMBootloader -----> VZLinuxBootLoader (direct kernel boot)
            |
            +-- ImageBuilder -----> Nix-based VM image building
            |
            +-- HardwareDetector -> system resource detection + recommendations
            |
            +-- ModelCatalog -----> local LLM model registry
            |
            +-- ModelManager -----> model download + lifecycle
```

The launcher uses Apple's Virtualization.framework (`VZVirtualMachine`) to run a NixOS guest with direct Linux kernel boot. The host shares directories into the VM via virtio-fs (workspace, profile data, model files).

## Directory Structure

```
sigil-launcher-macos/
+-- Package.swift              # SPM manifest (library + executable + tests)
+-- Makefile                   # Build/run/image-extraction shortcuts
+-- SigilLauncher/
|   +-- App/
|   |   +-- SigilLauncherApp.swift     # @main entry point
|   +-- Models/
|   |   +-- LauncherProfile.swift      # Persisted settings (JSON)
|   |   +-- ModelCatalog.swift         # Available local LLM models
|   |   +-- ModelManager.swift         # Model download manager
|   |   +-- VMState.swift             # VM lifecycle state enum
|   +-- Services/
|   |   +-- HardwareDetector.swift     # RAM/CPU/disk/GPU detection
|   |   +-- ImageBuilder.swift         # Nix flake generation + build
|   +-- VM/
|   |   +-- VMBootloader.swift         # Linux boot loader config
|   |   +-- VMConfiguration.swift      # Full VM config builder
|   |   +-- VMManager.swift            # Start/stop/health monitoring
|   +-- Views/
|       +-- ConfigurationView.swift    # Preferences window
|       +-- LauncherView.swift         # Main launcher window
|       +-- SetupWizard.swift          # First-run wizard
+-- Tests/
|   +-- LauncherProfileTests.swift
|   +-- ModelCatalogTests.swift
|   +-- HardwareDetectorTests.swift
|   +-- ImageBuilderTests.swift
+-- .github/workflows/
    +-- ci.yml                 # GitHub Actions CI
```

## First-Run Wizard

On first launch (no `~/.sigil/launcher/settings.json` found), the app presents a six-step setup wizard:

1. **Welcome** -- introduction screen
2. **Hardware Detection** -- scans RAM, CPU, disk, GPU; checks minimum requirements
3. **Resource Allocation** -- sliders for VM memory and CPU cores (based on recommendations)
4. **Tool Selection** -- editor (VS Code / Neovim / both / none), container engine, shell, notification level
5. **Model Selection** -- choose a local LLM model or cloud-only inference
6. **Build** -- generates a Nix flake and builds the VM image

## Configuration

Settings are persisted at `~/.sigil/launcher/settings.json` as a JSON-encoded `LauncherProfile`. Key fields:

| Field | Default | Description |
|-------|---------|-------------|
| `memorySize` | 4 GB | VM RAM in bytes |
| `cpuCount` | 2 | VM CPU cores |
| `workspacePath` | `~/workspace` | Host directory mounted as `/workspace` in VM |
| `editor` | `vscode` | Editor to install (`vscode`, `neovim`, `both`, `none`) |
| `containerEngine` | `docker` | Container engine (`docker`, `none`) |
| `shell` | `zsh` | Default shell (`zsh`, `bash`) |
| `notificationLevel` | 2 | 0=silent, 1=digest, 2=ambient, 3=conversational, 4=autonomous |
| `modelId` | `nil` | Selected local model ID, or nil for cloud-only |
| `sshPort` | 2222 | Forwarded SSH port |

Changing editor, container engine, shell, or model requires a VM image rebuild. Memory, CPU, and notification level changes take effect on next VM start.

### VM Image Artifacts

Built images are stored at `~/.sigil/images/`:
- `vmlinuz` -- Linux kernel
- `initrd` -- initial ramdisk
- `sigil-vm.img` -- root disk image

### Local Models

Downloaded models are stored at `~/.sigil/models/`. Available models:

| Model | Size | Min VM RAM |
|-------|------|------------|
| Qwen 2.5 1.5B (Q4) | 1.0 GB | 3 GB |
| Phi-3 Mini 3.8B (Q4) | 2.5 GB | 5 GB |
| LLaMA 3.1 8B (Q4) | 4.5 GB | 8 GB |

## Troubleshooting

**"Nix is not installed"** -- Install Nix from https://nixos.org/download/ and restart the app. The launcher checks `/nix/var/nix/profiles/default/bin/nix`, `/usr/local/bin/nix`, and `/opt/homebrew/bin/nix`.

**"Sigil requires at least 8GB of system RAM"** -- The launcher enforces a minimum 8 GB system RAM requirement. Machines below this threshold cannot run the VM with adequate resources.

**"No VM image found"** -- Click "Build Image" in the launcher view or re-run the setup wizard. Building requires Nix and an internet connection for the first build.

**"SSH did not become available"** -- The VM may be slow to boot. Check the serial console output (printed to stdout). Verify the kernel and initrd paths are correct in settings.

**"sigild did not start"** -- The daemon may not be installed in the VM image. Rebuild the image with `make extract-vm-image`.

**VM crashes immediately** -- Ensure the disk image exists and is not corrupted. Delete `~/.sigil/images/sigil-vm.img` and rebuild.

**Build takes a long time** -- First Nix builds download and compile the entire NixOS system. Subsequent builds are incremental. Batch configuration changes before rebuilding.

## License

Apache License 2.0
