# AGENTS.md - Guide for Coding Agents

This document provides essential information for AI coding agents working on the nixos-apple-silicon repository.

## Project Overview

This repository provides Apple Silicon support for NixOS, including kernel packages, bootloader configuration, and hardware-specific modules. It relies heavily on Asahi Linux's work and aims to replicate their reference distro experience.

## Build & Development Commands

### Nix Flake Commands

```bash
# Enter development shell (includes formatter)
nix develop

# Build packages
nix build .#uboot-asahi              # Build U-Boot bootloader
nix build .#linux-asahi              # Build Asahi Linux kernel
nix build .#installer-bootstrap      # Build installer ISO

# Build with different nixpkgs versions
nix build --override-input nixpkgs nixpkgs/nixos-unstable .#linux-asahi
nix build --override-input nixpkgs nixpkgs/master .#linux-asahi

# Build all packages
nix run nixpkgs#nix-fast-build -- --no-nom --skip-cached -f .#packages
```

### Formatting & Checks

```bash
# Format all Nix files using nixfmt-tree
nix fmt

# Check formatting
nix flake check

# Format specific file
nixfmt <file.nix>
```

### Testing

```bash
# Build and test a NixOS configuration with the module
nixos-rebuild build --flake .#<hostname>

# Test installer ISO
nix build .#installer-bootstrap
# ISO will be in ./result/iso/
```

### Cross-Compilation

This project supports cross-compilation from x86_64-linux to aarch64-linux:

```bash
# Cross-compile from x86_64 (automatically handled by flake)
nix build .#packages.x86_64-linux.linux-asahi
```

## Code Style & Conventions

### Nix Language

**Formatting**: Use `nixfmt-tree` (configured as default formatter in flake.nix)
- 2-space indentation
- Trailing commas in multi-line lists/sets
- Function arguments aligned vertically when multi-line
- Use `inherit` for cleaner attribute passing

**Import Style**:
```nix
# Function arguments - alphabetical, multi-line for readability
{
  config,
  lib,
  pkgs,
  ...
}:

# Imports in modules
imports = [
  ./submodule1
  ./submodule2
];
```

**Naming Conventions**:
- Package names: `linux-asahi`, `uboot-asahi` (lowercase with hyphens)
- Module options: `hardware.asahi.enable` (nested attributes with dots)
- Local variables: `camelCase` or `snake_case` (be consistent within file)
- Constants: Generally `UPPER_CASE` in structured configs

**Types & Options**:
```nix
# Always specify types for NixOS options
options.hardware.asahi.enable = lib.mkOption {
  type = lib.types.bool;
  default = true;
  description = ''
    Clear, multi-line description.
  '';
};

# Use mkIf for conditional configuration
config = lib.mkIf cfg.enable {
  # configuration here
};
```

**Priority/Overrides**:
- Use `lib.mkDefault` for soft defaults (priority 1000)
- Use `lib.mkOverride <priority>` for specific priority levels
  - 900: Higher than mkDefault but lower than explicit settings
  - 800: For important defaults that should be easily overrideable
- Use `lib.mkForce` to force a value (priority 50)

### Package Definitions

**fetchFromGitHub**: Use `tag` attribute for releases when possible:
```nix
src = fetchFromGitHub {
  owner = "AsahiLinux";
  repo = "linux";
  tag = "asahi-6.18.10-1";  # Preferred over rev for tagged releases
  hash = "sha256-...";
};
```

For non-release commits, use `rev`:
```nix
src = fetchFromGitHub {
  owner = "AsahiLinux";
  repo = "linux";
  rev = "61b6e714dd19b7bee1c0e6ec4234199e640c2932";
  hash = "sha256-...";
};
```

**Kernel Configuration**: Use `structuredExtraConfig` with `lib.kernel` helpers:
```nix
structuredExtraConfig = with lib.kernel; {
  ARM64_16K_PAGES = yes;
  HID_APPLE = module;
  # Clear comments explaining why options are needed
};
```

### Error Handling & Warnings

```nix
# Use lib.warnIf for warnings about known issues
lib.warnIf
  (condition)
  ''
    Warning message explaining the issue.
    Include links to relevant issues/documentation.
  ''
  value
```

### Comments

- Use `#` for inline comments
- Document **why**, not **what** - the code shows what
- Add references to upstream sources (Asahi scripts, kernel docs)
- Include issue/PR links for workarounds
- Example:
```nix
# U-Boot does not support EFI variables
boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
```

## Repository Structure

```
.
├── apple-silicon-support/
│   ├── packages/            # Package derivations
│   │   ├── linux-asahi/     # Asahi Linux kernel
│   │   ├── uboot-asahi/     # U-Boot bootloader
│   │   └── overlay.nix      # Nixpkgs overlay
│   └── modules/             # NixOS modules
│       ├── kernel/          # Kernel configuration
│       ├── boot-m1n1/       # m1n1 bootloader setup
│       ├── peripheral-firmware/
│       └── sound/
├── iso-configuration/       # Installer ISO configuration
├── docs/                    # User documentation
├── flake.nix               # Flake definition
└── default.nix             # Legacy Nix compatibility
```

## Important Principles

1. **Stay aligned with Asahi Linux**: Use their versions/configs as reference
2. **Cross-compilation support**: Ensure packages build on both aarch64 and x86_64
3. **Minimal divergence**: Don't accept significant deviations from Asahi reference distro
4. **Document hardware quirks**: Apple Silicon has specific requirements - document them
5. **Binary cache friendly**: Keep builds reproducible for cache hits

## Making Changes

### Adding a New Package

1. Create derivation in `apple-silicon-support/packages/<name>/default.nix`
2. Add to `overlay.nix`
3. Export in `flake.nix` packages output if needed
4. Test cross-compilation from x86_64

### Modifying the Kernel

1. Edit `apple-silicon-support/packages/linux-asahi/default.nix`
2. Update version, modDirVersion, tag/rev, and hash
3. Adjust `structuredExtraConfig` if needed
4. Test build: `nix build .#linux-asahi`
5. Rebuild installer if kernel is updated

### Adding Kernel Variants

To support multiple kernel branches (e.g., default and experimental):

1. Create new package: `packages/linux-asahi-<variant>/default.nix`
2. Add to overlay with distinct name: `linux-asahi-<variant>`
3. Export in `flake.nix` packages output
4. Allow selection via:
```nix
boot.kernelPackages = pkgs.linux-asahi-<variant>;
```

**Example: Fairydust Kernel (DP-ALT Mode)**

The `linux-asahi-fairydust` package provides experimental DisplayPort alternate mode support:

```nix
# In your configuration.nix
boot.kernelPackages = pkgs.linux-asahi-fairydust;
```

**Warning**: This is experimental and based on the upstream fairydust branch which contains
device tree hacks. Use only if you need DP-ALT mode support and are willing to test
experimental features.

Build and test:
```bash
# Build the fairydust kernel
nix build .#linux-asahi-fairydust

# Test in a NixOS configuration
nixos-rebuild build --flake .#<hostname>
```

Update to latest fairydust commit:
1. Find latest commit: https://github.com/AsahiLinux/linux/commits/fairydust
2. Update `rev` and `hash` in `packages/linux-asahi-fairydust/default.nix`
3. Update version string to include new short commit hash

## Troubleshooting

- **Build fails with formatting error**: Run `nix fmt`
- **Hash mismatch**: Update `hash` after changing `tag`/`rev`
- **Module conflicts**: Check priority with `lib.mkOverride`
- **Cross-build issues**: Ensure derivation uses correct `stdenv`

## Resources

- [Asahi Linux kernel](https://github.com/AsahiLinux/linux)
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nixpkgs Manual](https://nixos.org/manual/nixpkgs/stable/)
- [Project docs](docs/)
