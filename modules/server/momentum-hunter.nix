{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.services.momentum-hunter;

  # Fetch strategies from GitHub repo
  strategySource = pkgs.fetchFromGitHub {
    owner = "ControlStackAI";
    repo = "momentum-hunter";
    rev = cfg.rev;
    sha256 = cfg.srcHash;
  };

  # Generate Freqtrade config.json from Nix
  freqtradeConfig = {
    trading_mode = "spot";
    margin_mode = "";
    max_open_trades = cfg.maxOpenTrades;
    stake_currency = "USDT";
    stake_amount = "unlimited";
    tradable_balance_ratio = 0.99;
    fiat_display_currency = "USD";
    dry_run = cfg.dryRun;
    dry_run_wallet = cfg.initialCapital;
    cancel_open_orders_on_exit = false;
    exchange = {
      name = "kraken";
      # Injected at runtime from sops secrets
      key = "";
      secret = "";
      ccxt_config.enableRateLimit = true;
      ccxt_async_config.enableRateLimit = true;
      pair_whitelist = cfg.pairWhitelist;
      pair_blacklist = [
        ".*UP/USDT"
        ".*DOWN/USDT"
        ".*BEAR/USDT"
        ".*BULL/USDT"
      ];
    };
    entry_pricing = {
      price_side = "same";
      use_order_book = true;
      order_book_top = 1;
      price_last_balance = 0.0;
      check_depth_of_market = {
        enabled = false;
        bids_to_ask_delta = 1;
      };
    };
    exit_pricing = {
      price_side = "same";
      use_order_book = true;
      order_book_top = 1;
    };
    order_types = {
      entry = "limit";
      exit = "limit";
      emergency_exit = "market";
      force_entry = "market";
      force_exit = "market";
      stoploss = "market";
      stoploss_on_exchange = true;
      stoploss_on_exchange_interval = 60;
      stoploss_on_exchange_limit_ratio = 0.99;
    };
    pairlists = [
      { method = "StaticPairList"; }
    ];
    webhook = {
      enabled = cfg.slackWebhookSecret != null;
      url = "";
      webhookentry.value = "🟢 Entering {pair} at {limit:.8f} | Strategy: {strategy} | Reason: {enter_tag}";
      webhookexit.value = "🔴 Exiting {pair} at {limit:.8f} | Profit: {profit_amount:.2f} USDT ({profit_ratio:.2%}) | Reason: {exit_reason}";
      webhookstatus.value = "ℹ️ MomentumHunter: {status}";
    };
    bot_name = "MomentumHunter";
    initial_state = "running";
    internals.process_throttle_secs = 5;
  };

  configJson = pkgs.writeText "freqtrade-config.json" (builtins.toJSON freqtradeConfig);

in {
  options.services.momentum-hunter = {
    enable = lib.mkEnableOption "Momentum Hunter autonomous crypto trading bot";

    rev = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Git rev (branch/tag/commit) of ControlStackAI/momentum-hunter";
    };

    srcHash = lib.mkOption {
      type = lib.types.str;
      default = lib.fakeSha256;
      description = "SHA256 of the source. Set to empty string and build to get the real hash.";
    };

    strategy = lib.mkOption {
      type = lib.types.str;
      default = "MultiStrategy";
      description = "Freqtrade strategy class name";
    };

    dryRun = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Paper trading mode (no real money). Flip to false + rebuild to go live.";
    };

    initialCapital = lib.mkOption {
      type = lib.types.float;
      default = 100.0;
      description = "Starting capital in USDT (dry_run wallet size)";
    };

    maxOpenTrades = lib.mkOption {
      type = lib.types.int;
      default = 5;
      description = "Maximum simultaneous open trades";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/momentum-hunter";
      description = "Persistent data directory (trades DB, logs, data cache)";
    };

    krakenApiKeySecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "sops secret name for Kraken API key";
    };

    krakenSecretSecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "sops secret name for Kraken API secret";
    };

    slackWebhookSecret = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "sops secret name for Slack webhook URL";
    };

    pairWhitelist = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "SOL/USDT" "PEPE/USDT" "FET/USDT" "AVAX/USDT" "LINK/USDT"
        "DOT/USDT" "NEAR/USDT" "INJ/USDT" "ARB/USDT" "OP/USDT"
        "MATIC/USDT" "ATOM/USDT" "FIL/USDT" "APT/USDT" "SUI/USDT"
        "DOGE/USDT" "RENDER/USDT" "TIA/USDT" "SEI/USDT" "TAO/USDT"
      ];
      description = "Trading pair whitelist";
    };

    dockerImage = lib.mkOption {
      type = lib.types.str;
      default = "freqtradeorg/freqtrade:stable";
      description = "Freqtrade Docker image to use";
    };
  };

  config = lib.mkIf cfg.enable {
    # Docker is required
    virtualisation.docker.enable = true;

    # System user
    users.users.momentum-hunter = {
      isSystemUser = true;
      group = "momentum-hunter";
      home = cfg.dataDir;
      createHome = true;
    };
    users.groups.momentum-hunter = {};

    # sops secrets (conditionally defined)
    sops.secrets = lib.mkMerge [
      (lib.mkIf (cfg.krakenApiKeySecret != null) {
        ${cfg.krakenApiKeySecret} = {
          owner = "momentum-hunter";
          mode = "0400";
          restartUnits = [ "momentum-hunter.service" ];
        };
      })
      (lib.mkIf (cfg.krakenSecretSecret != null) {
        ${cfg.krakenSecretSecret} = {
          owner = "momentum-hunter";
          mode = "0400";
          restartUnits = [ "momentum-hunter.service" ];
        };
      })
      (lib.mkIf (cfg.slackWebhookSecret != null) {
        ${cfg.slackWebhookSecret} = {
          owner = "momentum-hunter";
          mode = "0400";
          restartUnits = [ "momentum-hunter.service" ];
        };
      })
    ];

    # Main trading service
    systemd.services.momentum-hunter = {
      description = "Momentum Hunter - Autonomous Crypto Trading Bot";
      after = [ "network-online.target" "docker.service" ];
      wants = [ "network-online.target" ];
      requires = [ "docker.service" ];
      wantedBy = [ "multi-user.target" ];

      path = [ pkgs.docker pkgs.jq ];

      preStart = let
        krakenKeyPath = if cfg.krakenApiKeySecret != null
          then config.sops.secrets.${cfg.krakenApiKeySecret}.path
          else null;
        krakenSecretPath = if cfg.krakenSecretSecret != null
          then config.sops.secrets.${cfg.krakenSecretSecret}.path
          else null;
        webhookPath = if cfg.slackWebhookSecret != null
          then config.sops.secrets.${cfg.slackWebhookSecret}.path
          else null;
      in ''
        # Create directory structure
        mkdir -p ${cfg.dataDir}/{user_data/strategies,user_data/data,user_data/logs,config}

        # Copy strategies from Nix store (declarative source of truth)
        rm -f ${cfg.dataDir}/user_data/strategies/*.py
        cp ${strategySource}/user_data/strategies/*.py ${cfg.dataDir}/user_data/strategies/ 2>/dev/null || true

        # Generate config with secrets injected
        cp ${configJson} ${cfg.dataDir}/config/config.json
        chmod 600 ${cfg.dataDir}/config/config.json

        ${lib.optionalString (krakenKeyPath != null && krakenSecretPath != null) ''
          KRAKEN_KEY=$(cat ${krakenKeyPath})
          KRAKEN_SECRET=$(cat ${krakenSecretPath})
          jq --arg key "$KRAKEN_KEY" --arg secret "$KRAKEN_SECRET" \
            '.exchange.key = $key | .exchange.secret = $secret' \
            ${cfg.dataDir}/config/config.json > ${cfg.dataDir}/config/config.tmp.json
          mv ${cfg.dataDir}/config/config.tmp.json ${cfg.dataDir}/config/config.json
        ''}

        ${lib.optionalString (webhookPath != null) ''
          WEBHOOK=$(cat ${webhookPath})
          jq --arg url "$WEBHOOK" '.webhook.url = $url' \
            ${cfg.dataDir}/config/config.json > ${cfg.dataDir}/config/config.tmp.json
          mv ${cfg.dataDir}/config/config.tmp.json ${cfg.dataDir}/config/config.json
        ''}

        chown -R momentum-hunter:momentum-hunter ${cfg.dataDir}
      '';

      script = ''
        # Stop any existing container
        docker stop momentum-hunter 2>/dev/null || true
        docker rm momentum-hunter 2>/dev/null || true

        exec docker run --rm \
          --name momentum-hunter \
          -v ${cfg.dataDir}/user_data:/freqtrade/user_data \
          -v ${cfg.dataDir}/config/config.json:/freqtrade/config/config.json:ro \
          ${cfg.dockerImage} \
          trade \
          --config /freqtrade/config/config.json \
          --strategy ${cfg.strategy} \
          --db-url sqlite:////freqtrade/user_data/tradesv3.sqlite
      '';

      serviceConfig = {
        Type = "simple";
        Restart = "on-failure";
        RestartSec = 30;
        # Security
        ProtectHome = true;
        PrivateTmp = true;
        NoNewPrivileges = true;
      };
    };

    # One-shot: pre-pull Docker image so first start isn't slow
    systemd.services.momentum-hunter-pull = {
      description = "Pull Freqtrade Docker image";
      after = [ "network-online.target" "docker.service" ];
      wants = [ "network-online.target" ];
      requires = [ "docker.service" ];
      before = [ "momentum-hunter.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.docker}/bin/docker pull ${cfg.dockerImage}";
        RemainAfterExit = true;
      };
    };
  };
}
