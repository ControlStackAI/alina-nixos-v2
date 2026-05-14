{
  description = "OpenClaw on NixOS — blank slate";

  inputs = {
    nix-openclaw.url = "github:openclaw/nix-openclaw";
    nixpkgs.follows = "nix-openclaw/nixpkgs";
    home-manager.follows = "nix-openclaw/home-manager";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-openclaw,
    disko,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      overlays = [nix-openclaw.overlays.default];
    };
  in {
    nixosConfigurations.alina = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        disko.nixosModules.disko
        ./hosts/alina/hardware-configuration.nix
        ./hosts/alina/disko.nix
        ./hosts/alina/config.nix
      ];
    };

    homeConfigurations.matthew = home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        nix-openclaw.homeManagerModules.openclaw
        ./home/matthew.nix
      ];
    };

    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [git just nix-output-monitor home-manager];
    };

    formatter.${system} = pkgs.alejandra;
  };
}
