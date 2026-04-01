{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.openclaw;

  # OpenClaw package — fixed-output derivation that fetches + installs in one step.
  # This is the pragmatic approach: npm packages without lockfiles can't use
  # buildNpmPackage, and the Nix sandbox blocks network in normal derivations.
  # A fixed-output derivation gets network access and is content-addressed by hash.
  #
  # To update: change version, set outputHash to "" , build, and Nix will tell you the correct hash.
  openclawNodeModules = pkgs.stdenvNoCC.mkDerivation {
    pname = "openclaw-node-modules";
    version = cfg.version;

    # Fixed-output derivation — gets network access during build
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = cfg.npmDepsHash;

    nativeBuildInputs = with pkgs; [
      nodejs_22
      python3
      pkg-config
      cacert
      curl
    ];

    buildInputs = with pkgs; [
      vips
      glib
    ];

    SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
    NODE_OPTIONS = "--dns-result-order=ipv4first";

    dontUnpack = true;
    dontConfigure = true;
    dontFixup = true;  # FODs must not reference store paths

    buildPhase = ''
      runHook preBuild

      export HOME=$(mktemp -d)

      mkdir -p pkg
      cd pkg

      # Download tarball directly
      curl -sL "https://registry.npmjs.org/openclaw/-/openclaw-${cfg.version}.tgz" -o openclaw.tgz
      tar xzf openclaw.tgz --strip-components=1
      rm openclaw.tgz

      # Install production dependencies (network available in FOD)
      npm install --production --no-audit --no-fund --ignore-scripts 2>&1

      # Install acpx into the extensions dir (OpenClaw expects it at dist/extensions/acpx/node_modules/.bin/acpx)
      if [ -d "dist/extensions/acpx" ]; then
        cd dist/extensions/acpx
        npm install --production --no-audit --no-fund 2>&1
        cd ../../..
      fi

      # Clean up npm cache artifacts
      rm -rf "$HOME/.npm" .cache

      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      cp -a . $out
      runHook postInstall
    '';
  };

  openclawPkg = pkgs.stdenv.mkDerivation {
    pname = "openclaw";
    version = cfg.version;

    dontUnpack = true;

    installPhase = ''
      mkdir -p $out/lib/openclaw $out/bin

      # Copy pre-built node_modules derivation
      cp -a ${openclawNodeModules}/* $out/lib/openclaw/

      # Create bin wrapper
      cat > $out/bin/openclaw <<EOF
      #!/usr/bin/env bash
      exec ${pkgs.nodejs_22}/bin/node $out/lib/openclaw/openclaw.mjs "\$@"
      EOF
      chmod +x $out/bin/openclaw
      substituteInPlace $out/bin/openclaw --replace '      #!' '#!'
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

    npmDepsHash = lib.mkOption {
      type = lib.types.str;
      description = "Hash of the fixed-output derivation containing openclaw + node_modules. Set to empty string and build to get the correct hash.";
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

        # acpx is baked into the package (installed during FOD build into dist/extensions/acpx/node_modules)

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
        # Explicit PATH: nix packages + imperative ACP tools from bootstrap-acp.sh
        PATH = lib.mkForce (lib.concatStringsSep ":" [
          "${cfg.dataDir}/.npm-global/bin"
          "${pkgs.nodejs_22}/bin"
          "${pkgs.git}/bin"
          "${pkgs.openssh}/bin"
          "${pkgs.bash}/bin"
          "${pkgs.coreutils}/bin"
          "/run/current-system/sw/bin"
        ]);
        # ACP tools (claude, codex, mcporter) installed via bootstrap-acp.sh
        npm_config_prefix = "${cfg.dataDir}/.npm-global";
        HOME = cfg.dataDir;
        NODE_ENV = "production";
        OPENCLAW_PORT = toString cfg.port;
        # nix-ld: allow prebuilt ELF binaries (codex-acp, claude-acp) to find shared libs
        NIX_LD = "/run/current-system/sw/share/nix-ld/lib/ld.so";
        NIX_LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
        LD_LIBRARY_PATH = "/run/current-system/sw/share/nix-ld/lib";
        LOCALE_ARCHIVE = "${pkgs.glibcLocales}/lib/locale/locale-archive";
        TZDIR = "${pkgs.tzdata}/share/zoneinfo";
      } // cfg.extraEnvironment;
    };
  };
}
