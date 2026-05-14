{...}: {
  home.username = "matthew";
  home.homeDirectory = "/home/matthew";
  home.stateVersion = "24.11";
  programs.home-manager.enable = true;

  # Dual-instance OpenClaw setup (prod + dev). Both disabled in the blank slate —
  # flip enable=true and supply channel/auth config when you're ready to use them.
  programs.openclaw = {
    enable = true;
    instances = {
      prod = {
        enable = false;
        gatewayPort = 18789;
      };
      dev = {
        enable = false;
        gatewayPort = 18790;
      };
    };
  };
}
