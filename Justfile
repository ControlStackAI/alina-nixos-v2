default:
    @just --list

build:
    nix build .#nixosConfigurations.alina.config.system.build.toplevel

switch:
    sudo nixos-rebuild switch --flake .#alina

fmt:
    nix fmt
