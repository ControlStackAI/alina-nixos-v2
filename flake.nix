{
  description = "flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # Pin nvf to a recent commit that should have better LSP support
    nvf.url = "github:notashelf/nvf";
    nvf.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # Secrets management
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Optional hardware profiles and declarative partitioning
    nixos-hardware.url = "github:NixOS/nixos-hardware";
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Dev hygiene: pre-commit hooks
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    pre-commit-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    nvf,
    home-manager,
    sops-nix,
    nixos-hardware,
    disko,
    pre-commit-hooks,
    ...
  }: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
  in {
    homeConfigurations = {
      matthew = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          sops-nix.homeManagerModules.sops
          nvf.homeManagerModules.default
          ./home/matthew/home.nix
        ];
      };

      "matthew-mangano" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          sops-nix.homeManagerModules.sops
          nvf.homeManagerModules.default
          ./home/matthew-mangano/home.nix
        ];
      };
    };

    nixosConfigurations.controlstackos = nixpkgs.lib.nixosSystem {
      system = system;

      modules = [
        ./hosts/controlstackos/hardware-configuration.nix
        ./modules/common.nix
        ./modules/desktop.nix
        ./hosts/controlstackos/config.nix

        # Optional imports (uncomment and adjust as needed):
        # nixos-hardware.nixosModules.lenovo-thinkpad-x1-9th-gen
        # disko.nixosModules.disko

        # Existing modules preserved
        nvf.nixosModules.default
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          # Back up conflicting files instead of failing activation
          home-manager.backupFileExtension = "backup";
          # Make sops-nix options available to Home Manager
          home-manager.sharedModules = [
            sops-nix.homeManagerModules.sops
            nvf.homeManagerModules.default
          ];
          home-manager.users.matthew = import ./home/matthew.nix;
        }
      ];
    };

    # Minimal VM configuration for smoke tests (desktop profile)
    nixosConfigurations.vm = nixpkgs.lib.nixosSystem {
      system = system;
      modules = [
        nvf.nixosModules.default
        ./modules/common.nix
        ./modules/vm-guest.nix
        {
          networking.hostName = "vm";
          # A minimal root filesystem to satisfy NixOS assertions for VM builds
          fileSystems."/" = {
            device = "nodev";
            fsType = "tmpfs";
            options = ["mode=0755"];
          };
          # No bootloader needed for qemu-vm builder
          boot.loader.grub.enable = false;
          boot.loader.systemd-boot.enable = false;
        }
      ];
    };

    # VM smoke test for the ALINA v2 server profile
    nixosConfigurations.vm-server = nixpkgs.lib.nixosSystem {
      system = system;
      modules = [
        ./modules/server.nix
        ./modules/vm-guest.nix
        sops-nix.nixosModules.sops
        {
          networking.hostName = "vm-server";
          fileSystems."/" = {
            device = "nodev";
            fsType = "tmpfs";
            options = ["mode=0755"];
          };
          boot.loader.grub.enable = false;
          boot.loader.systemd-boot.enable = false;
          # Disable services that need real hardware/secrets in CI
          services.caddy.enable = false;
          services.postgresql.enable = false;
          systemd.services.openclaw-gateway.enable = false;
        }
      ];
    };

    # GCP — production server configuration (alina-prod VM)
    # Target: GCP VM running OpenClaw + ALINA Comms (BIOS/GRUB, ext4, no bcachefs)
    nixosConfigurations.gcp = nixpkgs.lib.nixosSystem {
      system = system;
      modules = [
        ./hosts/gcp/hardware.nix
        ./modules/server.nix
        ./hosts/gcp/config.nix

        disko.nixosModules.disko
        ./hosts/gcp/disk-config.nix

        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.sharedModules = [
            sops-nix.homeManagerModules.sops
          ];
          home-manager.users.matthew = import ./home/matthew-server/home.nix;
        }
      ];
    };

    # ALINA v2 — headless server configuration
    # Target: second laptop (22-core / 30 GB) running OpenClaw + ALINA Comms
    nixosConfigurations.alina = nixpkgs.lib.nixosSystem {
      system = system;
      modules = [
        ./hosts/alina/hardware-configuration.nix
        # server.nix imports the required core modules directly (no desktop/nvf deps)
        ./modules/server.nix
        ./hosts/alina/config.nix

        disko.nixosModules.disko
        ./hosts/alina/disko.nix

        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "backup";
          home-manager.sharedModules = [
            sops-nix.homeManagerModules.sops
          ];
          home-manager.users.matthew = import ./home/matthew-server/home.nix;
        }
      ];
    };

    # Bcachefs-aware installer ISO for controlstackos (HP Firefly)
    nixosConfigurations.controlstackos-installer = nixpkgs.lib.nixosSystem {
      system = system;
      modules = [
        # Minimal installer image with a recent kernel, without ZFS.
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
        (
          { lib, pkgs, ... }:
            {
              nix.settings.experimental-features = ["nix-command" "flakes"];

              # Tools we want on the installer for this workflow.
              environment.systemPackages = with pkgs; [
                git
                disko
                bcachefs-tools
                keyutils
              ];

              # Ensure the installer kernel/initrd support bcachefs.
              boot.supportedFilesystems = ["bcachefs"];
            }
        )
      ];
    };

    # Installer ISO for ALINA v2 (same bcachefs-capable base as controlstackos-installer)
    nixosConfigurations.alina-installer = nixpkgs.lib.nixosSystem {
      system = system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal-new-kernel-no-zfs.nix"
        (
          {
            lib,
            pkgs,
            ...
          }: {
            nix.settings.experimental-features = ["nix-command" "flakes"];

            environment.systemPackages = with pkgs; [
              git
              disko
              bcachefs-tools
              keyutils
            ];

            boot.supportedFilesystems = ["bcachefs"];
          }
        )
      ];
    };

    # per-system outputs
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        git
        sops
        age
        just
        statix
        deadnix
        alejandra
        nil
        nix-output-monitor
        pre-commit
      ];
      shellHook = ''
        pre-commit install --install-hooks || true
        echo "Dev shell ready: nix fmt, statix, deadnix, pre-commit hooks installed."
      '';
    };

    formatter.${system} = pkgs.alejandra;

    # Checks: lint, pre-commit, and host builds
    checks.${system} = {
      default = pkgs.stdenv.mkDerivation {
        name = "lint";
        src = ./.;
        buildCommand = ''
          ${pkgs.statix}/bin/statix check .
          ${pkgs.deadnix}/bin/deadnix --fail .
          mkdir -p $out
        '';
      };

      controlstackos = self.nixosConfigurations.controlstackos.config.system.build.toplevel;
      vm = self.nixosConfigurations.vm.config.system.build.vm;
      vm-server = self.nixosConfigurations.vm-server.config.system.build.vm;
    };

    # Optional: Nix-native pre-commit runner (invoked via nix build)
    packages.${system}.pre-commit-check = pre-commit-hooks.lib.${system}.run {
      src = ./.;
      hooks = {
        alejandra.enable = true;
        statix.enable = true;
        deadnix.enable = true;
        shellcheck.enable = true;
        shfmt.enable = true;
        markdownlint.enable = true;
      };
    };
  };
}
