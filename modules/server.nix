{
  config,
  pkgs,
  ...
}: {
  # Server profile for ALINA v2
  # Imports the subset of core modules suitable for a headless server.
  # Desktop/GUI modules (hyprland, sound, fonts, screenshots, desktop-tools,
  # neovim NVF) are intentionally excluded.

  imports = [
    ./core/locale.nix
    ./core/users.nix
    ./core/services.nix # ssh, tailscale, lid-switch, fstrim, etc.
    ./core/security.nix
    ./core/system.nix # kernel, sysctl, nix settings
    ./core/git-repo-manager.nix
    # networking.nix is imported per-host (hosts/alina/config.nix)

    # Server-specific modules
    ./server/packages.nix
    ./server/openclaw.nix
    ./server/caddy.nix
    ./server/postgres.nix
    ./server/docker.nix
    ./server/comms.nix
  ];

  # Enable zsh system-wide (users.nix sets it as default shell for matthew)
  programs.zsh.enable = true;
  programs.direnv.enable = true;
  programs.direnv.nix-direnv.enable = true;

  # Enable nix-ld so generic Linux ELF binaries work (e.g. codex-acp, claude-acp)
  # Required for ACP coding agents which ship prebuilt x86_64 binaries.
  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      # Common libs needed by Node.js native addons and prebuilt binaries
      libcap
      stdenv.cc.cc.lib  # libstdc++, libgcc_s
      zlib
      openssl
      libffi
      glib
    ];
  };

  # No Warp or desktop overlays needed on the server
}
