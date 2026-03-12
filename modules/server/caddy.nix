{
  config,
  pkgs,
  lib,
  ...
}: {
  # Caddy reverse proxy for ALINA v2
  #
  # Virtual hosts:
  #   comms.controlstackai.com  → ALINA Comms backend (port 4000)
  #   openclaw.controlstackai.com → OpenClaw Gateway (port 3000)
  #
  # Caddy handles automatic HTTPS via ACME (Let's Encrypt / ZeroSSL).
  # Make sure DNS for each vhost points to this machine's public IP before
  # deploying.
  #
  # Ports 80 and 443 must be open in any firewall / cloud security group.

  services.caddy = {
    enable = true;

    # Global Caddy settings
    globalConfig = ''
      email admin@controlstackai.com
    '';

    # Per-site virtual host blocks
    virtualHosts = {
      "comms.controlstackai.com" = {
        extraConfig = ''
          reverse_proxy localhost:4000
        '';
      };

      "openclaw.controlstackai.com" = {
        extraConfig = ''
          reverse_proxy localhost:3000
        '';
      };
    };
  };

  # Open firewall for HTTP/HTTPS
  networking.firewall.allowedTCPPorts = [80 443];
}
