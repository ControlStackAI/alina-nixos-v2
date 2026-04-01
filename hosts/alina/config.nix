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

  # ── sops-nix secrets ──────────────────────────────────────────────────────
  # Age key derived from SSH host key (no separate key file needed).
  # Decrypt: ssh-to-age < /etc/ssh/ssh_host_ed25519_key
  sops.defaultSopsFile = ../../secrets/alina.yaml;
  sops.age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];

  # ── OpenClaw Gateway (declarative) ──────────────────────────────────────
  services.openclaw = {
    enable = true;
    version = "2026.4.1";
    npmDepsHash = lib.fakeHash;
    configFile = ../../openclaw/openclaw.json5;
    agentsDir = ../../openclaw/agents;
    secretsFile = config.sops.secrets."openclaw_env".path;
  };

  # OpenClaw environment file (multi-var dotenv format)
  sops.secrets."openclaw_env" = {
    owner = "openclaw";
    group = "openclaw";
    mode = "0400";
    restartUnits = ["openclaw-gateway.service"];
  };

  # Comms secrets (individual values)
  sops.secrets."comms_db_password" = {
    owner = "root";
    mode = "0400";
  };

  sops.secrets."comms_jwt_secret" = {
    owner = "root";
    mode = "0400";
  };
}
