{
  config,
  pkgs,
  lib,
  ...
}: {
  # Host-specific toggles and imports
  imports = [
    ../../modules/core/networking.nix
    ../../modules/core/bootloader.nix
    ../../modules/core/cloudflare-warp.nix
    ../../modules/core/nvidia.nix
  ];

  # Enable booting from a bcachefs root filesystem on this host.
  # The actual partitioning and filesystem creation is handled by
  # hosts/controlstackos/disko.nix.
  boot.supportedFilesystems = ["bcachefs"];

  # Root filesystem is a single bcachefs volume; no subvolume mounts.
  # The root device/fsType come from hardware-configuration.nix.
  # Per-host kernel customization examples (override core/system.nix defaults):
  #
  # Choose kernel series:
  #   boot.kernelPackages = pkgs.linuxPackages_latest;   # default
  #   boot.kernelPackages = pkgs.linuxPackages_lts;
  #   boot.kernelPackages = pkgs.linuxPackages_hardened;
  #   boot.kernelPackages = pkgs.linuxPackages_zen;
  #
  # Extra kernel parameters (boot-time):
  #   boot.kernelParams = [
  #     "quiet"
  #     "loglevel=3"
  #   ];
  #
  # Extra kernel modules from the chosen kernelPackages set:
  #   boot.extraModulePackages = [
  #     pkgs.linuxPackages_lts.v4l2loopback
  #   ];

  # Example secret mapping guarded by file existence (non-breaking placeholder)
  sops.secrets."example-password" = lib.mkIf (builtins.pathExists ../../secrets/example.yaml) {
    sopsFile = ../../secrets/example.yaml;
  };
  # Usage example:
  # services.postgresql = {
  #   enable = true;
  #   # passwordFile will be provided by sops-nix at build time
  #   authentication = {
  #     passwordFile = config.sops.secrets."example-password".path;
  #   };
  # };
}
