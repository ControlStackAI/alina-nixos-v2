# alina-nixos-v2

OpenClaw on NixOS — blank slate, pinned to `openclaw@2026.5.12-beta.7`.

Single host: `alina` (server laptop).

## Build

```sh
nix build .#nixosConfigurations.alina.config.system.build.toplevel
```

## Switch (on alina)

```sh
sudo nixos-rebuild switch --flake .#alina
```

## Bumping OpenClaw

1. Update `version` in `hosts/alina/config.nix`.
2. Set `npmDepsHash = "";` and rebuild — Nix prints the correct hash.
3. Paste it back in.
