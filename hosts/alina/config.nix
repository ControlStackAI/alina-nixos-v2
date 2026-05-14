{
  config,
  pkgs,
  lib,
  ...
}: {
  networking.hostName = "alina";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.supportedFilesystems = ["bcachefs"];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  users.users.matthew = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    openssh.authorizedKeys.keys = [];
  };

  services.openssh.enable = true;

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    jq
  ];

  services.openclaw = {
    enable = true;
    version = "2026.5.12-beta.7";
    npmDepsHash = "sha256-xencRelJ1QgyWm+V8DFWyU7aZ5k9PbU13zoDvpfnXvM=";
  };

  system.stateVersion = "26.05";
}
