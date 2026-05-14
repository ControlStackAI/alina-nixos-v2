{...}: {
  home.username = "matthew";
  home.homeDirectory = "/home/matthew";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # Dual-instance OpenClaw setup (prod + dev) per upstream nix-openclaw docs.
  # Blank slate: gateways come up in local mode with placeholder auth tokens;
  # no channels, plugins, or secrets are wired. Add channels.telegram (or
  # discord/slack) + a real token under instances.<name>.config when you're
  # ready to expose either gateway.
  programs.openclaw = {
    enable = true;
    instances = {
      prod = {
        enable = true;
        gatewayPort = 18789;
        config.gateway = {
          mode = "local";
          auth.token = "REPLACE-ME-PROD";
        };
      };
      dev = {
        enable = true;
        gatewayPort = 18790;
        config.gateway = {
          mode = "local";
          auth.token = "REPLACE-ME-DEV";
        };
      };
    };
  };
}
