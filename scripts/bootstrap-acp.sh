#!/usr/bin/env bash
# bootstrap-acp.sh — Install ACP runtime tools for the openclaw user.
# These are npm globals that update frequently, so we keep them imperative.
# Run this after nixos-rebuild switch on a fresh machine.
#
# Usage: sudo -u openclaw bash scripts/bootstrap-acp.sh
#    or: sudo bash scripts/bootstrap-acp.sh  (auto-detects openclaw user)

set -euo pipefail

OPENCLAW_USER="${OPENCLAW_USER:-openclaw}"
OPENCLAW_HOME="${OPENCLAW_HOME:-/var/lib/openclaw}"
NPM_PREFIX="${OPENCLAW_HOME}/.npm-global"

# If running as root, re-exec as the openclaw user
if [[ "$(id -u)" == "0" ]]; then
  exec sudo -u "$OPENCLAW_USER" \
    OPENCLAW_USER="$OPENCLAW_USER" \
    OPENCLAW_HOME="$OPENCLAW_HOME" \
    NPM_PREFIX="$NPM_PREFIX" \
    bash "$0" "$@"
fi

echo "=== ALINA ACP Bootstrap ==="
echo "User: $(whoami)"
echo "Home: $OPENCLAW_HOME"
echo "npm prefix: $NPM_PREFIX"
echo ""

# Ensure npm global dir exists
mkdir -p "$NPM_PREFIX"
npm config set prefix "$NPM_PREFIX"

# ACP runtime tools — these are what OpenClaw needs to spawn coding agents
ACP_PACKAGES=(
  "openclaw"                    # CLI (backup, also provides openclaw command)
  "@anthropic-ai/claude-code"   # Claude Code (ACP runtime)
  "@openai/codex"               # Codex (ACP runtime)
  "mcporter"                    # MCP transport bridge
  "pnpm"                        # Package manager (used by some tools)
  "acpx"                        # ACP transport (OpenClaw sub-agent harness)
  "@googleworkspace/cli"          # Google Workspace CLI (Gmail, Calendar, Drive, etc.)
)

echo "Installing ACP packages..."
for pkg in "${ACP_PACKAGES[@]}"; do
  echo "  → $pkg"
  npm install -g "$pkg" --no-audit --no-fund 2>&1 | tail -1
done

echo ""
echo "=== Installed binaries ==="
ls -1 "$NPM_PREFIX/bin/" 2>/dev/null || echo "(none)"

echo ""
echo "=== Verification ==="
export PATH="$NPM_PREFIX/bin:$PATH"
for cmd in openclaw claude codex mcporter pnpm gws; do
  if command -v "$cmd" &>/dev/null; then
    echo "  ✅ $cmd: $(command -v $cmd)"
  else
    echo "  ❌ $cmd: not found"
  fi
done

echo ""
echo "Bootstrap complete."
