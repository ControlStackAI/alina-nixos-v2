{
  config,
  pkgs,
  lib,
  ...
}: {
  # ALINA Comms — auto-start Docker Compose stack on boot
  #
  # Manages the Comms API + Postgres + Redis containers.
  # Repo lives at /opt/alina-comms (cloned manually).

  systemd.services.alina-comms = {
    description = "ALINA Comms Platform";
    after = ["docker.service" "network-online.target"];
    wants = ["network-online.target"];
    requires = ["docker.service"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      WorkingDirectory = "/opt/alina-comms";
      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d --remove-orphans";
      ExecStop = "${pkgs.docker-compose}/bin/docker-compose down";
      TimeoutStartSec = "120";
    };
  };
}
