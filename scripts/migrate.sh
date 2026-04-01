#!/usr/bin/env bash
# migrate.sh — Self-migration script for ALINA.
# Exports all runtime state from the current host, or imports it onto a new one.
# The NixOS config (alina-nixos-v2 repo) handles the OS + packages + services.
# This script handles the MUTABLE state that lives outside the repo.
#
# Usage:
#   ./migrate.sh export              # Pack runtime state → tarball
#   ./migrate.sh import <tarball>    # Unpack tarball → new host
#   ./migrate.sh verify              # Health check after migration
#   ./migrate.sh full <target-host>  # Full migration: export + transfer + import + verify

set -euo pipefail

OPENCLAW_HOME="/var/lib/openclaw"
EXPORT_DIR="/tmp/alina-migration"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TARBALL="alina-state-${TIMESTAMP}.tar.gz.enc"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[migrate]${NC} $*"; }
warn() { echo -e "${YELLOW}[migrate]${NC} $*"; }
err()  { echo -e "${RED}[migrate]${NC} $*" >&2; }

cmd_export() {
  log "=== ALINA State Export ==="
  log "Exporting mutable state from $(hostname)..."

  rm -rf "$EXPORT_DIR"
  mkdir -p "$EXPORT_DIR"

  # 1. OpenClaw runtime state (memory, sessions, logs, npm-global)
  log "Exporting OpenClaw runtime state..."
  sudo tar czf "$EXPORT_DIR/openclaw-state.tar.gz" \
    -C "$OPENCLAW_HOME" \
    --exclude='.openclaw/agents'  \
    --exclude='.openclaw/openclaw.json' \
    .openclaw/ .npm-global/ .npmrc 2>/dev/null || true

  # 2. Zbook workspace state (this is the primary ALINA workspace on zbook)
  # Only relevant if migrating FROM zbook
  if [[ -d "$HOME/.openclaw/workspace" ]]; then
    log "Exporting zbook workspace..."
    tar czf "$EXPORT_DIR/zbook-workspace.tar.gz" \
      -C "$HOME/.openclaw" \
      workspace/ 2>/dev/null || true
  fi

  # 3. SSH keys (encrypted separately)
  if [[ -d "$HOME/.ssh" ]]; then
    log "Exporting SSH keys..."
    tar czf "$EXPORT_DIR/ssh-keys.tar.gz" \
      -C "$HOME" .ssh/ 2>/dev/null || true
  fi

  # 4. Docker volumes (ALINA Comms data)
  if docker ps -q --filter name=alina-comms 2>/dev/null | grep -q .; then
    log "Exporting ALINA Comms database..."
    docker exec alina-comms-postgres-1 \
      pg_dump -U comms comms > "$EXPORT_DIR/comms-db.sql" 2>/dev/null || warn "Could not dump comms DB"
  fi

  # 5. sops age key (needed to decrypt secrets on new host)
  if [[ -f "$HOME/.config/sops/age/keys.txt" ]]; then
    log "Exporting sops age key..."
    cp "$HOME/.config/sops/age/keys.txt" "$EXPORT_DIR/sops-age-key.txt"
  fi

  # 6. NixOS generation info (for rollback reference)
  log "Recording system info..."
  cat > "$EXPORT_DIR/source-info.txt" << EOF
hostname: $(hostname)
date: $(date -Iseconds)
nixos-generation: $(nixos-rebuild list-generations 2>/dev/null | grep 'True' | head -1 || echo "unknown")
openclaw-version: $(cat "$OPENCLAW_HOME/.openclaw/package.json" 2>/dev/null | jq -r '.version' 2>/dev/null || echo "unknown")
kernel: $(uname -r)
EOF

  # Pack everything into an encrypted tarball
  log "Creating encrypted tarball..."
  tar czf - -C "$EXPORT_DIR" . | \
    openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -out "/tmp/$TARBALL"

  # Cleanup unencrypted export
  rm -rf "$EXPORT_DIR"

  log "=== Export complete ==="
  log "Tarball: /tmp/$TARBALL"
  log "Size: $(du -h /tmp/$TARBALL | cut -f1)"
  log ""
  log "Transfer to new host:"
  log "  scp /tmp/$TARBALL <new-host>:/tmp/"
  log "  ssh <new-host> 'cd ~/alina-nixos-v2 && ./scripts/migrate.sh import /tmp/$TARBALL'"
}

cmd_import() {
  local tarball="${1:?Usage: migrate.sh import <tarball>}"

  log "=== ALINA State Import ==="
  log "Importing state onto $(hostname)..."

  # Decrypt and unpack
  mkdir -p "$EXPORT_DIR"
  openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -in "$tarball" | \
    tar xzf - -C "$EXPORT_DIR"

  log "Source: $(cat $EXPORT_DIR/source-info.txt 2>/dev/null || echo 'unknown')"

  # 1. OpenClaw runtime state
  if [[ -f "$EXPORT_DIR/openclaw-state.tar.gz" ]]; then
    log "Restoring OpenClaw runtime state..."
    sudo tar xzf "$EXPORT_DIR/openclaw-state.tar.gz" -C "$OPENCLAW_HOME/"
    sudo chown -R openclaw:openclaw "$OPENCLAW_HOME/"
  fi

  # 2. SSH keys
  if [[ -f "$EXPORT_DIR/ssh-keys.tar.gz" ]]; then
    log "Restoring SSH keys..."
    tar xzf "$EXPORT_DIR/ssh-keys.tar.gz" -C "$HOME/"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/id_*" 2>/dev/null || true
  fi

  # 3. sops age key
  if [[ -f "$EXPORT_DIR/sops-age-key.txt" ]]; then
    log "Restoring sops age key..."
    mkdir -p "$HOME/.config/sops/age"
    cp "$EXPORT_DIR/sops-age-key.txt" "$HOME/.config/sops/age/keys.txt"
    chmod 600 "$HOME/.config/sops/age/keys.txt"
  fi

  # 4. ALINA Comms database
  if [[ -f "$EXPORT_DIR/comms-db.sql" ]]; then
    log "Restoring ALINA Comms database..."
    if docker ps -q --filter name=alina-comms-postgres 2>/dev/null | grep -q .; then
      docker exec -i alina-comms-postgres-1 psql -U comms comms < "$EXPORT_DIR/comms-db.sql" || \
        warn "Could not restore comms DB — may need manual import"
    else
      warn "ALINA Comms not running — DB dump saved at $EXPORT_DIR/comms-db.sql"
    fi
  fi

  # Cleanup
  rm -rf "$EXPORT_DIR"

  # Restart OpenClaw to pick up restored state
  log "Restarting OpenClaw gateway..."
  sudo systemctl restart openclaw-gateway || warn "Could not restart openclaw-gateway"

  log "=== Import complete ==="
  log "Run: ./scripts/migrate.sh verify"
}

cmd_verify() {
  log "=== ALINA Health Check ==="
  local ok=0 fail=0
  set +e

  check() {
    if eval "$2" &>/dev/null; then
      echo -e "  ${GREEN}✅${NC} $1"
      ((ok++))
    else
      echo -e "  ${RED}❌${NC} $1"
      ((fail++))
    fi
  }

  check "NixOS booted"          "test -f /etc/NIXOS"
  check "OpenClaw service"      "systemctl is-active openclaw-gateway"
  check "OpenClaw port open"    "curl -sf http://localhost:18789/health || curl -sf http://localhost:18789/"
  check "Tailscale connected"   "tailscale status --json | jq -e '.Self.Online'"
  check "Docker running"        "docker info"
  check "PostgreSQL running"    "systemctl is-active postgresql"
  check "Caddy running"         "systemctl is-active caddy"
  check "SSH reachable"         "ssh -o ConnectTimeout=2 localhost true 2>/dev/null || ss -tlnp | grep -q ':3965'"
  check "sops secrets decrypted" "test -f /run/secrets/openclaw_env"
  check "ACP: claude"           "sudo test -x $OPENCLAW_HOME/.npm-global/bin/claude"
  check "ACP: codex"            "sudo test -x $OPENCLAW_HOME/.npm-global/bin/codex"
  check "ACP: mcporter"         "sudo test -x $OPENCLAW_HOME/.npm-global/bin/mcporter"
  check "OpenClaw config"       "sudo test -f $OPENCLAW_HOME/.openclaw/openclaw.json"
  check "Memory files"          "sudo find $OPENCLAW_HOME/.openclaw/agents/ -name MEMORY.md 2>/dev/null | head -1"

  echo ""
  log "Results: $ok passed, $fail failed"

  if [[ $fail -eq 0 ]]; then
    log "🟢 All checks passed — ALINA is healthy."
  else
    warn "🟡 $fail check(s) failed — review above."
  fi
}

cmd_full() {
  local target="${1:?Usage: migrate.sh full <target-host>}"

  log "=== Full Migration to $target ==="

  # Export
  cmd_export

  # Transfer
  log "Transferring to $target..."
  scp "/tmp/$TARBALL" "$target:/tmp/"

  # Remote: clone repo, rebuild, import, bootstrap, verify
  log "Running remote setup..."
  ssh "$target" bash << REMOTE
    set -euo pipefail
    echo "=== Remote setup on \$(hostname) ==="

    # Clone NixOS config if not present
    if [[ ! -d ~/alina-nixos-v2 ]]; then
      git clone https://github.com/ControlStackAI/alina-nixos-v2.git ~/alina-nixos-v2
    else
      cd ~/alina-nixos-v2 && git pull
    fi

    cd ~/alina-nixos-v2

    # Rebuild NixOS
    echo "Running nixos-rebuild switch..."
    sudo nixos-rebuild switch --flake .#alina

    # Import state
    echo "Importing state..."
    ./scripts/migrate.sh import /tmp/$TARBALL

    # Bootstrap ACP tools
    echo "Installing ACP tools..."
    sudo bash ./scripts/bootstrap-acp.sh

    # Verify
    echo "Verifying..."
    ./scripts/migrate.sh verify
REMOTE

  log "=== Migration complete ==="
}

case "${1:-help}" in
  export)  cmd_export ;;
  import)  cmd_import "$2" ;;
  verify)  cmd_verify ;;
  full)    cmd_full "$2" ;;
  *)
    echo "Usage: migrate.sh <command>"
    echo ""
    echo "Commands:"
    echo "  export              Pack runtime state into encrypted tarball"
    echo "  import <tarball>    Restore state from tarball onto this host"
    echo "  verify              Health check — verify all services are running"
    echo "  full <target-host>  Complete migration: export → transfer → rebuild → import → verify"
    echo ""
    echo "Prerequisites:"
    echo "  - NixOS with alina-nixos-v2 flake config"
    echo "  - Run bootstrap-acp.sh after import for ACP tools"
    ;;
esac
