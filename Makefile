SIGIL_OS_DIR ?= ../sigil-os
IMAGE_DIR ?= $(HOME)/.sigil/images
PROFILE_DIR ?= $(HOME)/.sigil/profiles/default

.PHONY: build run clean release setup extract-vm-image

# Build the Swift launcher
build:
	swift build

# Run the launcher (debug)
run: setup
	swift run SigilLauncher

# Build release binary
release:
	swift build -c release

clean:
	swift package clean

# Create required directories for first run
setup:
	@mkdir -p $(IMAGE_DIR)
	@mkdir -p $(PROFILE_DIR)
	@mkdir -p $(HOME)/.config/sigil-shell

# Extract VM image artifacts from a NixOS build.
# Requires: aarch64-linux nix builder (native or remote).
# Run this once, or whenever the VM config changes.
extract-vm-image: setup
	@echo "Building launcher VM image (aarch64-linux)..."
	cd $(SIGIL_OS_DIR) && nix build .#nixosConfigurations.sigil-launcher.config.system.build.toplevel --out-link result-launcher
	cd $(SIGIL_OS_DIR) && nix build .#packages.aarch64-linux.launcher-kernel --out-link result-kernel
	cd $(SIGIL_OS_DIR) && nix build .#packages.aarch64-linux.launcher-initrd --out-link result-initrd
	@echo "Copying kernel..."
	cp -L $(SIGIL_OS_DIR)/result-kernel/bzImage $(IMAGE_DIR)/vmlinuz
	@echo "Copying initrd..."
	cp -L $(SIGIL_OS_DIR)/result-initrd/initrd $(IMAGE_DIR)/initrd
	@echo "Creating disk image (2GB)..."
	@if [ ! -f $(IMAGE_DIR)/sigil-vm.img ]; then \
		dd if=/dev/zero of=$(IMAGE_DIR)/sigil-vm.img bs=1M count=2048 2>/dev/null; \
		echo "Disk image created. Run 'make install-to-disk' to install NixOS."; \
	else \
		echo "Disk image already exists. Delete it first to recreate."; \
	fi
	@echo "VM image artifacts ready at $(IMAGE_DIR)/"
	@ls -lh $(IMAGE_DIR)/

# Install the NixOS system to the raw disk image.
# This is done once; subsequent boots use the installed system.
install-to-disk:
	@echo "Installing NixOS to disk image..."
	@echo "This requires a running aarch64-linux system or QEMU."
	@echo "Steps:"
	@echo "  1. Boot the disk image in QEMU with the kernel+initrd"
	@echo "  2. Format /dev/vda as ext4"
	@echo "  3. Mount and copy the system closure"
	@echo "  4. Install bootloader entries"
	@echo ""
	@echo "Automated installation coming in a future update."
