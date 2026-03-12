{
  config,
  pkgs,
  ...
}: {
  # Docker for ALINA Comms containers and the aero pipeline
  #
  # The 'matthew' user is added to the docker group so rootless docker-compose
  # commands work without sudo.  The daemon itself runs as root (standard mode).

  virtualisation.docker = {
    enable = true;
    # Auto-start Docker at boot
    enableOnBoot = true;
    # Use iptables integration for container networking
    autoPrune = {
      enable = true;
      # Prune dangling images / stopped containers weekly
      dates = "weekly";
    };
  };

  # Give the service user and matthew docker access
  users.users.matthew.extraGroups = ["docker"];
}
