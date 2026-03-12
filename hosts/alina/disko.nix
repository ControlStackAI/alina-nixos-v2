{
  # Declarative disk layout for the ALINA server laptop
  # (22-core / 30 GB — bcachefs root, EFI/systemd-boot)
  #
  # ⚠️  DEVICE PATH: Update `device` below to match your actual NVMe device.
  #     Run `lsblk` on the target machine and look for the NVMe disk.
  #     Common values: /dev/nvme0n1, /dev/nvme1n1
  #
  # To apply:
  #   sudo nix run github:nix-community/disko -- --mode disko hosts/alina/disko.nix

  disko.devices = {
    disk = {
      # Change "nvme0n1" and the `device` value if your NVMe device differs.
      nvme0n1 = {
        type = "disk";
        device = "/dev/nvme0n1"; # <-- VERIFY on target hardware
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              name = "ESP";
              size = "512M";
              type = "ef00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = ["fmask=0077" "dmask=0077"];
              };
            };

            root = {
              name = "root";
              end = "-0";
              content = {
                type = "filesystem";
                format = "bcachefs";
                # Single-device server tuning:
                # - lz4 for fast foreground I/O
                # - zstd:3 background compression for long-term savings
                extraArgs = [
                  "--compression=lz4"
                  "--background_compression=zstd:3"
                  "--metadata_replicas=2"
                  "--data_replicas=1"
                ];
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}
