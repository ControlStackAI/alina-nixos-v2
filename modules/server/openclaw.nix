{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.openclaw;

  # OpenClaw package — built from npm tarball with native deps
  openclawPkg = pkgs.stdenv.mkDerivation rec {
    pname = "openclaw";
    version = cfg.version;

    src = pkgs.fetchurl {
      url = "https://registry.npmjs.org/openclaw/-/openclaw-${version}.tgz";
      hash = cfg.srcHash;
    };

    nativeBuildInputs = with pkgs; [
      nodejs_22
      python3          # needed by node-gyp for some native modules
      pkg-config
    ];

    buildInputs = with pkgs; [
      # Native deps for sharp, canvas, etc.
      vips
      pixman
      cairo
      pango
      libjpeg
      giflib
      librsvg
      glib
    ];

    # npm needs a writable HOME
    HOME = "$TMPDIR";

    unpackPhase = ''
      mkdir -p $out/lib/openclaw
      cd $out/lib/openclaw
      tar xzf $src --strip-components=1
    '';

    buildPhase = ''
      cd $out/lib/openclaw

      # Install production deps only
      ${pkgs.nodejs_22}/bin/npm install \
        --production \
        --no-optional \
        --ignore-scripts \
        --prefer-offline 2>&1 || true

      # Rebuild native modules against system libs
      ${pkgs.nodejs_22}/bin/npm rebuild 2>&1 || true
    '';

    installPhase = ''
      # Create bin wrapper
      mkdir -p $out/bin
      cat > $out/bin/openclaw <<'WRAPPER'
      #!/usr/bin/env bash
      exec ${pkgs.nodejs_22}/bin/node $out/lib/openclaw/openclaw.mjs "$@"
      WRAPPER
      chmod +x $out/bin/openclaw

      # Fix the wrapper to expand $out at build time
      substituteInPlace $out/bin/openclaw \
        --replace '$out' "$out"
    '';

    meta = {
      description = "Multi-channel AI gateway with extensible messaging integrations";
      homepage = "https://github.com/openclaw/openclaw";
      license = lib.licenses.mit;
      mainProgram = "openclaw";
    };
  };

in {
  options.services.openclaw = {
    enable = lib.mkEnableOption "OpenClaw Gateway";

    version = lib.mkOption {
      type = lib.types.str;
      default = "2026.4.1";
      description = "OpenClaw version from npm registry.";
    };

    srcHash = lib.mkOption {
      type = lib.types.str;
      description = "SRI hash of the npm tarball. Get with: nix-prefetch-url --type sha256 --unpack <url>";
      # To update: nix-prefetch-url --type sha256 --unpack https://registry.npmjs.org/openclaw/-/openclaw-VERSION.tgz
    };

    package = lib.mkOption {
      type = lib.types.package;
      default = openclawPkg;
      defaultText = lib.literalExpression "built from npm tarball";
      description = ''
        The OpenClaw package to use. Override this to use a fork build:
          services.openclaw.package = pkgs.callPackage ./my-openclaw-fork.nix {};
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Port for the OpenClaw gateway.";
    };

    configFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to openclaw.json5 (or .json) config file. Will be converted to JSON and deployed.";
    };

    agentsDir = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to agents/ directory to sync into the OpenClaw data dir.";
    };

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/openclaw";
      description = "Working directory for the OpenClaw service.";
    };

    secretsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Path to an EnvironmentFile with secrets (OPENCLAW_GATEWAY_TOKEN, API keys, etc).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = "openclaw";
      description = "System user to run OpenClaw as.";
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "openclaw";
      description = "System group for the OpenClaw user.";
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      description = "Additional environment variables for the OpenClaw service.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Create system user
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      shell = pkgs.bash;
      description = "OpenClaw Gateway service user";
    };
    users.groups.${cfg.group} = {};

    # Declaratively deploy config from repo → data dir
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir}/.openclaw 0750 ${cfg.user} ${cfg.group} -"
    ];

    systemd.services.openclaw-gateway = {
      description = "OpenClaw Gateway";
      documentation = ["https://github.com/openclaw/openclaw"];
      after = ["network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];

      # Deploy declarative config before start (does NOT touch runtime dirs like logs/, subagents/, etc.)
      preStart = ''
        mkdir -p ${cfg.dataDir}/.openclaw

        # Deploy config file (convert json5 → json if needed)
        if echo "${cfg.configFile}" | grep -q '\.json5$'; then
          ${pkgs.nodejs_22}/bin/node -e "
            const fs = require('fs');
            const json5 = require('${cfg.package}/lib/openclaw/node_modules/json5');
            const src = fs.readFileSync('${cfg.configFile}', 'utf8');
            fs.writeFileSync('${cfg.dataDir}/.openclaw/openclaw.json', JSON.stringify(json5.parse(src), null, 2));
          "
        else
          cp ${cfg.configFile} ${cfg.dataDir}/.openclaw/openclaw.json
        fi

        ${lib.optionalString (cfg.agentsDir != null) ''
          # Sync agent workspaces (additive — won't delete runtime state in other dirs)
          ${pkgs.rsync}/bin/rsync -a ${cfg.agentsDir}/ ${cfg.dataDir}/.openclaw/agents/
        ''}

        # Ensure correct ownership
        chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}/.openclaw/
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;

        ExecStart = "${cfg.package}/bin/openclaw gateway run";

        Restart = "on-failure";
        RestartSec = "10s";

        EnvironmentFile = lib.mkIf (cfg.secretsFile != null) cfg.secretsFile;

        # Hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        ReadWritePaths = [cfg.dataDir "/tmp"];
      };

      environment = {
        NODE_ENV = "production";
        OPENCLAW_PORT = toString cfg.port;
        # nix-ld: allow prebuilt ELF binaries (codex-acp, claude-acp) to find shared libs
        NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
        NIX_LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
        LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
      } // cfg.extraEnvironment;
    };
  };
}
