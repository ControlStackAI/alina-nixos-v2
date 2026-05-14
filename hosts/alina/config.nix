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
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    jq
  ];

  system.stateVersion = "26.05";
}
