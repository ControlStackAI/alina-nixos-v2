{
  config,
  pkgs,
  lib,
  ...
}: {
  # Minimal Home Manager config for the ALINA server.
  # Excludes: NVF/neovim, desktop, ghostty, k8s, xdg, screenshots.
  # Includes: shell, git, SSH, basic CLI tools, secrets.

  imports = [
    ../common/programs/zsh.nix
    ../common/programs/starship.nix
    ../common/programs/fzf.nix
    ../common/programs/shell-tools.nix
    ../common/programs/git.nix
    ../common/programs/ssh.nix
    ../common/secrets.nix
    ../common/hm-compat.nix
  ];

  home.username = "matthew";
  home.homeDirectory = "/home/matthew";
  home.stateVersion = "25.11";

  programs.home-manager.enable = true;

  # Minimal server CLI packages
  home.packages = with pkgs; [
    vim
    htop
    ncdu
    tree
  ];
}
