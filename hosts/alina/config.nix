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
    npmDepsHash = "sha256-iG3NNo5POVmbxTmGsfIeQV63xvqgXt6MPPhq/pwNtgE=";
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

  # ── Momentum Hunter (crypto trading bot) ────────────────────────────────
  services.momentum-hunter = {
    enable = true;
    strategy = "MultiStrategy";
    dryRun = true;  # Paper trading — flip to false + rebuild to go live
    initialCapital = 100.0;
    maxOpenTrades = 5;
    # Uncomment after adding secrets to secrets/alina.yaml:
    # krakenApiKeySecret = "momentum-hunter/kraken-api-key";
    # krakenSecretSecret = "momentum-hunter/kraken-secret";
    # slackWebhookSecret = "momentum-hunter/slack-webhook";
  };
}
