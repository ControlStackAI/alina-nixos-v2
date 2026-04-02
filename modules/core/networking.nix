{
  config,
  lib,
  pkgs,
  ...
}: {
  networking.hostName = lib.mkDefault "alina";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
}
