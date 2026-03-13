{
  config,
  pkgs,
  lib,
  ...
}: {
  # Caddy reverse proxy for ALINA v2
  #
  # Current setup: Tailscale-only access (home LAN, no public IP).
  # Uses Caddy's internal TLS or plain HTTP reverse proxy.
  #
  # When this moves to a public host or gets a Cloudflare tunnel,
  # switch the site addresses to real domains and Caddy will auto-HTTPS.

  services.caddy = {
    enable = true;

    globalConfig = ''
      email admin@controlstackai.com
    '';

    virtualHosts = {
      # ALINA Comms API — Docker container on port 8080
      ":8443" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:8080
        '';
      };

      # OpenClaw Gateway — systemd service on port 18789
      ":8444" = {
        extraConfig = ''
          tls internal
          reverse_proxy localhost:18789
        '';
      };

      # Health check / status page on port 80
      ":80" = {
        extraConfig = ''
          respond /health "OK" 200
          respond "ALINA v2 — use Tailscale to connect" 200
        '';
      };
    };
  };

  # Open firewall for Caddy ports
  networking.firewall.allowedTCPPorts = [80 443 8443 8444];
}
