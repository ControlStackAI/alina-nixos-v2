# NixOS • ALINA v2

[![nix](https://github.com/ManganoConsulting/nixos-nymeria/actions/workflows/nix.yml/badge.svg)](https://github.com/ManganoConsulting/nixos-nymeria/actions/workflows/nix.yml)

**ALINA v2** — Server-oriented NixOS config for the `alina` laptop (22-core / 30GB RAM), running OpenClaw Gateway + ALINA Comms.

Also retains the original **controlstackos** host (HP Firefly 16 G11 desktop workstation) as a reference config.

---

## Hosts

| Host | Purpose | Profile |
|------|---------|---------|
| `alina` | Server laptop — OpenClaw + ALINA Comms | `server.nix` |
| `controlstackos` | HP Firefly 16 G11 workstation | `common.nix` + `desktop.nix` |

---

## Stack

- **Filesystem:** bcachefs (NVMe, lz4 + zstd background compression)
- **Bootloader:** systemd-boot
- **Secrets:** sops-nix (AGE keys)
- **Disk layout:** disko (declarative partitioning)
- **Reverse proxy:** Caddy (automatic HTTPS)
- **Database:** PostgreSQL 16
- **Containers:** Docker
- **Packages:** nixpkgs-unstable (Node.js 22 LTS, upgradeable to 25.x)
- **Networking:** Tailscale + SSH (port 3965, key-only)

---

## Server Modules (`modules/server/`)

| Module | Purpose |
|--------|---------|
| `openclaw.nix` | OpenClaw Gateway systemd service |
| `caddy.nix` | Caddy reverse proxy (comms.controlstackai.com, openclaw.controlstackai.com) |
| `postgres.nix` | PostgreSQL 16 for ALINA Comms |
| `docker.nix` | Docker daemon + weekly prune |
| `packages.nix` | Server package set (Node.js, git, jq, docker, etc.) |

---

## Quick Start — ALINA Server

### 1. Boot the installer ISO

```bash
nix build .#nixosConfigurations.alina-installer.config.system.build.isoImage
```

Flash to USB and boot the target machine.

### 2. Partition with disko

```bash
# Verify NVMe device (update hosts/alina/disko.nix if not nvme0n1)
lsblk

sudo nix run github:nix-community/disko -- --mode disko /path/to/hosts/alina/disko.nix
```

### 3. Set up secrets

```bash
# On the alina machine, generate an age key:
age-keygen -o ~/.config/sops/age/keys.txt
grep 'public key' ~/.config/sops/age/keys.txt

# Back on dev machine — update .sops.yaml with alina's age public key, then:
cp secrets/alina.yaml.example secrets/alina.yaml
$EDITOR secrets/alina.yaml   # fill in real values
sops --age <ALINA_AGE_KEY> --encrypt --in-place secrets/alina.yaml
```

### 4. Install NixOS

```bash
sudo nixos-install --flake .#alina
```

### 5. Post-install: install OpenClaw

```bash
# As the openclaw user (or root):
npm install -g openclaw --prefix /var/lib/openclaw/.npm-global
systemctl enable --now openclaw-gateway
```

---

## Secrets Structure (`secrets/alina.yaml`)

| Key | Used by |
|-----|---------|
| `token` | openclaw_gateway_token → OpenClaw Gateway |
| `secret` | comms_api_key → ALINA Comms service |
| `password` | postgres_comms_password → PostgreSQL init |

See `secrets/alina.yaml.example` for the template.

---

## VM Smoke Tests

```bash
# Desktop profile (controlstackos)
nix build .#nixosConfigurations.vm.config.system.build.vm

# Server profile (alina)
nix build .#nixosConfigurations.vm-server.config.system.build.vm
```

---

## Dev Shell

```bash
nix develop
# Provides: git, sops, age, just, statix, deadnix, alejandra, nil, pre-commit
```

---

## Timezone / User

Timezone: `America/Los_Angeles` · Primary user: `matthew`

---

## Original controlstackos Config

The `controlstackos` host (HP Firefly 16 G11 desktop) is preserved in `hosts/controlstackos/` and `modules/desktop.nix` as a reference. It uses the full desktop profile (Hyprland, NVF/neovim, Warp terminal, etc.) and is not deployed on ALINA.
