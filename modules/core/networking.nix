{
  config,
  lib,
  pkgs,
  ...
}: {
  networking.hostName = lib.mkDefault "controlstackos";
  networking.networkmanager.enable = true;
  systemd.services.NetworkManager-wait-online.enable = false;
}
