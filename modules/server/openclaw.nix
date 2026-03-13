{
  config,
  pkgs,
  lib,
  ...
}: {
  # OpenClaw Gateway — systemd system service under a dedicated user
  #
  # Design notes (merged from alina-nixos v1 + alina-nixos-v2):
  #   - Runs as a dedicated `openclaw` system user (more secure than running as matthew)
  #   - Secrets loaded via sops-nix in dotenv format (multiple env vars in one file)
  #   - Service restarts automatically when the secrets file changes
  #   - Linger is NOT needed because this is a system service (not a user service)
  #
  # Prerequisites (run once after first deploy):
  #   sudo -u openclaw npm install -g openclaw
  #   # or manage via the openclaw user's home: /var/lib/openclaw/.npm-global
  #
  # Secrets file format (secrets/alina.yaml or secrets/gcp.yaml):
  #   openclaw_env: |
  #     OPENCLAW_GATEWAY_TOKEN=<token>
  #     OPENCLAW_PORT=18789
  #     NODE_ENV=production
  #     # ... any other vars openclaw needs

  users.users.openclaw = {
    isSystemUser = true;
    group = "openclaw";
    home = "/var/lib/openclaw";
    createHome = true;
    shell = pkgs.bash;
    description = "OpenClaw Gateway service user";
  };
  users.groups.openclaw = {};

  # sops-nix secret: gateway token (single-value, as a string).
  # The host config (hosts/*/config.nix) declares this secret pointing to the
  # host-specific secrets file (e.g. secrets/alina.yaml, secrets/gcp.yaml).
  # We reference it here via config.sops.secrets so we can conditionally use it.

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

      # openclaw is installed as a global npm package under the service user's home.
      # Adjust ExecStart after running: sudo -u openclaw npm install -g openclaw
      ExecStart = "/var/lib/openclaw/.npm-global/bin/openclaw gateway run";

      Restart = "on-failure";
      RestartSec = "10s";

      # Load secrets as environment variables from the sops-decrypted file.
      # The file path comes from config.sops.secrets."openclaw_gateway_token".path
      # when the secret is declared in the host config. Use EnvironmentFile if available.
      EnvironmentFile =
        if (config.sops.secrets ? "openclaw_env")
        then config.sops.secrets."openclaw_env".path
        else "/var/lib/openclaw/secrets.env";

      # Hardening
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ReadWritePaths = ["/var/lib/openclaw" "/tmp"];
    };

    environment = {
      NODE_ENV = "production";
      OPENCLAW_PORT = "18789";
      # npm global prefix scoped to service user home
      NPM_CONFIG_PREFIX = "/var/lib/openclaw/.npm-global";
      PATH = lib.mkForce "/var/lib/openclaw/.npm-global/bin:${pkgs.nodejs_22}/bin:/run/current-system/sw/bin:/usr/bin:/bin";
      # nix-ld: allow prebuilt ELF binaries (codex-acp, claude-acp) to find shared libs
      NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
      NIX_LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
    };
  };
}
