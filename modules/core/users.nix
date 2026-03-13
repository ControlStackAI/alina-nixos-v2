{
  config,
  pkgs,
  ...
}: {
  users.users.matthew = {
    isNormalUser = true;
    description = "Matthew";
    extraGroups = ["networkmanager" "wheel" "libvirtd" "docker"];
    shell = pkgs.zsh;
    # Authorize SSH public keys declaratively (Terminust phone key)
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILNiStJf28q66n4kNmRZwgqrop3YxEfRBPizE09Iwcxe matthew.mangano@gmail.com"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM6PLgONXIR7zwtQziGNxQIjJWa/MlOIHm1U/E69/+FH terminus-phone"
    ];
    packages = with pkgs; [];
  };

  # Autologin disabled on servers — use SSH key auth instead.
  # services.getty.autologinUser = "matthew";
}
