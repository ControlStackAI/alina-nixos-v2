{
  config,
  pkgs,
  lib,
  ...
}: {
  # Host-specific configuration for ALINA (22-core server laptop)
  imports = [
    ../../modules/core/bootloader.nix
    ../../modules/core/networking.nix
  ];

  networking.hostName = "alina";

  # bcachefs root filesystem support
  boot.supportedFilesystems = ["bcachefs"];

  # Latest kernel for best bcachefs + hardware support
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # sops-nix secrets for ALINA v2 services
  # Add secrets/alina.yaml (encrypted) with the keys below.
  # See secrets/README.md for key generation instructions.
  #
  # Required keys in secrets/alina.yaml:
  #   openclaw_gateway_token: "<openclaw gateway token>"
  #   comms_api_key:          "<ALINA Comms API key>"
  #   postgres_comms_password: "ALTER ROLE comms WITH PASSWORD '<password>';"
  #
  sops.secrets."openclaw_gateway_token" = lib.mkIf (builtins.pathExists ../../secrets/alina.yaml) {
    sopsFile = ../../secrets/alina.yaml;
    owner = "openclaw";
    mode = "0400";
  };

  sops.secrets."comms_api_key" = lib.mkIf (builtins.pathExists ../../secrets/alina.yaml) {
    sopsFile = ../../secrets/alina.yaml;
    owner = "matthew";
    mode = "0400";
  };

  # Allow SSH on non-standard port (inherits from services.nix) plus 80/443 for Caddy.
  # Extra ports if you need direct access to internal services during development:
  # networking.firewall.allowedTCPPorts = [ 5432 ];  # postgres (disable in prod)
}
