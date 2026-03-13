{
  config,
  pkgs,
  ...
}: {
  # Server packages for ALINA v2
  # Merged from alina-nixos v1 (packages.nix) + alina-nixos-v2 (server/packages.nix).
  # Desktop tools (ollama, python/transformers, GUI apps) intentionally excluded.

  environment.systemPackages = with pkgs; [
    # ── Core server tooling ──────────────────────────────────────────────────
    curl
    jq
    git
    wget
    htop
    tmux
    mosh # Mobile shell — survive flaky connections
    ripgrep
    fd # Fast find
    tree
    unzip
    zip
    bat # Better cat
    eza # Better ls
    fzf # Fuzzy finder
    neovim

    # ── Node.js runtime ──────────────────────────────────────────────────────
    # nodejs_25 is available in nixpkgs-unstable; fall back to _22 if not yet stable
    nodejs_22
    nodePackages.npm

    # ── Python (aero pipeline + scripts) ────────────────────────────────────
    python3
    python3Packages.pip

    # ── Cloud & infra ────────────────────────────────────────────────────────
    google-cloud-sdk # gcloud CLI
    gh # GitHub CLI

    # ── Container / orchestration ────────────────────────────────────────────
    docker
    docker-compose

    # ── TLS / PKI helpers ────────────────────────────────────────────────────
    openssl
    gnupg # GPG — age key management, signing

    # ── Shell environment ────────────────────────────────────────────────────
    zsh
    direnv

    # ── Media processing ─────────────────────────────────────────────────────
    ffmpeg # Audio/video (TTS, media ingestion, webcam snapshots)

    # ── Monitoring / diagnostics ─────────────────────────────────────────────
    lsof
    nettools
    iproute2
    tcpdump
    iotop
  ];

  # Shell defaults
  programs.zsh.enable = true;
  users.defaultUserShell = pkgs.zsh;

  # Direnv + nix-direnv integration
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  # Git global defaults
  programs.git = {
    enable = true;
    config = {
      init.defaultBranch = "main";
    };
  };

  # npm global packages directory note:
  # After deploy, run as the target user:
  #   mkdir -p ~/.npm-global
  #   npm config set prefix '~/.npm-global'
  #   npm install -g openclaw @openai/codex @anthropic-ai/claude-code
  # The openclaw user's npm prefix is set to /var/lib/openclaw/.npm-global via systemd env.
}
