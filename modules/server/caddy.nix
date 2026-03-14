{
  config,
  pkgs,
  lib,
  ...
}: {
  # Caddy reverse proxy for ALINA v2
  #
  # Tailscale-only access — no public HTTPS needed.
  # Tailscale already provides end-to-end encryption.
  # When exposing publicly, switch to domain-based vhosts for auto-HTTPS.

  services.caddy = {
    enable = true;

    globalConfig = ''
      email admin@controlstackai.com
      auto_https off
    '';

    virtualHosts = {
      # ALINA Comms API
      ":8443" = {
        extraConfig = ''
          reverse_proxy localhost:8080
        '';
      };

      # OpenClaw Gateway
      ":8444" = {
        extraConfig = ''
          reverse_proxy localhost:18789
        '';
      };

      # ALINA Comms Web Client + API (same origin)
      ":3000" = {
        extraConfig = ''
          handle /api/* {
            reverse_proxy localhost:8080
          }
          handle {
            reverse_proxy localhost:4173
          }
        '';
      };

      # ALINA Comms HTTPS (for mic/getUserMedia — requires secure context)
      "alina.tail90bbd0.ts.net:3443" = {
        extraConfig = ''
          tls /etc/caddy/alina.crt /etc/caddy/alina.key

          handle /api/* {
            reverse_proxy localhost:8080
          }
          handle {
            reverse_proxy localhost:4173
          }
        '';
      };

      # Health / status
      ":80" = {
        extraConfig = ''
          respond /health "OK" 200
          respond "ALINA v2" 200
        '';
      };
    };
  };

  networking.firewall.allowedTCPPorts = [80 3000 3443 8443 8444];
}
