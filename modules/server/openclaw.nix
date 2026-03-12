{
  config,
  pkgs,
  lib,
  ...
}: {
  # OpenClaw Gateway — systemd service
  #
  # Secrets are loaded via sops-nix. The gateway token is written to
  # /run/secrets/openclaw_gateway_token by sops-nix at activation time.
  #
  # Prerequisites (run once after first deploy):
  #   npm install -g openclaw
  #
  # The ExecStart path assumes openclaw is in the openclaw user's npm global bin.
  # Adjust NPM_PREFIX / ExecStart if you use a different install location.

  users.users.openclaw = {
    isSystemUser = true;
    group = "openclaw";
    home = "/var/lib/openclaw";
    createHome = true;
    description = "OpenClaw Gateway service user";
  };
  users.groups.openclaw = {};

  # sops-nix secret: gateway token.
  # Stored in secrets/alina.yaml (encrypted). Key name: openclaw_gateway_token.
  sops.secrets."openclaw_gateway_token" = lib.mkIf (builtins.pathExists ../../secrets/alina.yaml) {
    sopsFile = ../../secrets/alina.yaml;
    owner = "openclaw";
    mode = "0400";
  };

  systemd.services.openclaw-gateway = {
    description = "OpenClaw Gateway";
    documentation = ["https://github.com/controlstackai/openclaw"];
    after = ["network-online.target"];
    wants = ["network-online.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      User = "openclaw";
      Group = "openclaw";
      WorkingDirectory = "/var/lib/openclaw";

      # openclaw is installed as a global npm package under the service home.
      # The ExecStart uses node directly with the resolved main script path.
      # Update this path after running: npm install -g openclaw
      ExecStart = "${pkgs.nodejs_22}/bin/node /var/lib/openclaw/.npm-global/lib/node_modules/openclaw/bin/openclaw.js gateway start";

      Restart = "on-failure";
      RestartSec = "10s";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = ["/var/lib/openclaw"];
      PrivateTmp = true;
    };

    environment = {
      NODE_ENV = "production";
      OPENCLAW_PORT = "3000";
      # npm global prefix scoped to service home
      NPM_CONFIG_PREFIX = "/var/lib/openclaw/.npm-global";
    };
  };
}
