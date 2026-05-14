{
  description = "OpenClaw on NixOS — blank slate";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    disko,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {inherit system;};
  in {
    nixosConfigurations.alina = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        disko.nixosModules.disko
        ./modules/openclaw.nix
        ./hosts/alina/hardware-configuration.nix
        ./hosts/alina/disko.nix
        ./hosts/alina/config.nix
      ];
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [git just nix-output-monitor];
    };

    formatter.${system} = pkgs.alejandra;
  };
}
