{
  config,
  pkgs,
  lib,
  ...
}: {
  # PostgreSQL for ALINA Comms backend
  #
  # Creates a 'comms' database and 'comms' role.
  # Password is managed via sops-nix (see secrets/alina.yaml).
  #
  # The Comms app should connect to:
  #   postgresql://comms:<password>@localhost/comms

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;

    # Only listen on localhost; Caddy/app connects via Unix socket or 127.0.0.1
    settings = {
      listen_addresses = "127.0.0.1";
      max_connections = 100;
    };

    authentication = pkgs.lib.mkOverride 10 ''
      # TYPE  DATABASE  USER    ADDRESS       METHOD
      local   all       all                   trust
      host    all       all     127.0.0.1/32  md5
    '';

    ensureDatabases = ["comms"];
    ensureUsers = [
      {
        name = "comms";
        ensureDBOwnership = true;
      }
    ];

    # IMPORTANT: Set the actual password for 'comms' role via a post-start script
    # referencing the sops-managed secret. Example (uncomment and wire up):
    #
    # initialScript = config.sops.secrets."postgres_comms_password".path;
    #
    # Where secrets/alina.yaml contains:
    #   postgres_comms_password: "ALTER ROLE comms WITH PASSWORD 'your-secret';"
  };

  # Optional: automatic daily backups to /var/backup/postgres
  # systemd.services.postgres-backup = {
  #   description = "PostgreSQL daily backup";
  #   startAt = "daily";
  #   script = ''
  #     ${pkgs.postgresql_16}/bin/pg_dumpall -U postgres > /var/backup/postgres/dump_$(date +%Y%m%d).sql
  #   '';
  #   serviceConfig = { User = "postgres"; };
  # };
}
