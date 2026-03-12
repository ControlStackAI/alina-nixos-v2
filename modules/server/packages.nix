{
  config,
  pkgs,
  ...
}: {
  # Server packages for ALINA v2
  # Replaces ai-tools.nix — stripped of ollama, python/transformers, and desktop tools.
  # nodejs_23 is the latest stable in nixpkgs-unstable; update to nodejs_latest when 25.x lands.

  environment.systemPackages = with pkgs; [
    # Core server tooling
    curl
    jq
    git
    wget
    htop
    tmux
    ripgrep
    unzip
    zip

    # Node.js runtime (v22 LTS from nixpkgs-unstable; use nodejs_latest for v25.x when available)
    nodejs_22
    nodePackages.npm

    # Container / infra
    docker
    docker-compose

    # TLS / PKI helpers
    openssl
    certutil

    # Monitoring / diagnostics
    lsof
    nettools
    iproute2
    tcpdump
    iotop
  ];
}
