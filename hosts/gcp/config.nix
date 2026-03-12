{
  config,
  pkgs,
  lib,
  ...
}: {
  # GCP host-specific configuration for alina-prod (GCP VM)
  # Wired into flake.nix as nixosConfigurations.gcp
  # Uses modules/server.nix (headless server profile, no desktop/GUI)

  networking.hostName = "alina-prod";
  networking.useDHCP = lib.mkDefault true;
  # systemd-networkd / networkmanager not needed on GCP; DHCP handles everything
  networking.networkmanager.enable = false;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22 # SSH (standard — GCP initial deploy + nixos-anywhere)
      80 # Caddy HTTP
      443 # Caddy HTTPS
      18789 # OpenClaw gateway
      3334 # Voice-call plugin
    ];
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      } # Mosh
    ];
  };

  # GCP uses BIOS/GRUB — override the EFI defaults that may come from server.nix imports
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.grub = {
    enable = lib.mkForce true;
    devices = lib.mkForce ["/dev/sda"];
    efiSupport = false;
  };

  # Override SSH: GCP needs port 22 + PermitRootLogin for nixos-anywhere initial deploy.
  # After first deploy you can tighten this.
  services.openssh = {
    enable = true;
    ports = lib.mkForce [22];
    settings = lib.mkForce {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "yes"; # needed for nixos-anywhere
    };
  };

  # Authorized keys for matthew and root
  users.users.matthew.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILNiStJf28q66n4kNmRZwgqrop3YxEfRBPizE09Iwcxe matthew.mangano@gmail.com"
  ];
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILNiStJf28q66n4kNmRZwgqrop3YxEfRBPizE09Iwcxe matthew.mangano@gmail.com"
  ];

  # sops-nix secrets for GCP services.
  # Add secrets/gcp.yaml (encrypted) — see secrets/README.md for key generation.
  #
  # Required keys in secrets/gcp.yaml:
  #   openclaw_gateway_token: "<openclaw gateway token>"
  #   comms_api_key:          "<ALINA Comms API key>"
  #   postgres_comms_password: "ALTER ROLE comms WITH PASSWORD '<password>';"
  sops.secrets."openclaw_gateway_token" = lib.mkIf (builtins.pathExists ../../secrets/gcp.yaml) {
    sopsFile = ../../secrets/gcp.yaml;
    owner = "openclaw";
    mode = "0400";
  };
  sops.secrets."comms_api_key" = lib.mkIf (builtins.pathExists ../../secrets/gcp.yaml) {
    sopsFile = ../../secrets/gcp.yaml;
    owner = "matthew";
    mode = "0400";
  };
}
