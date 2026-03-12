# GCP disk layout: BIOS boot + ext4 root on /dev/sda
# No bcachefs — GCP does not support it.
{
  disko.devices = {
    disk.main = {
      type = "disk";
      device = "/dev/sda";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            size = "1M";
            # EF02 = BIOS boot partition; disko wires /dev/sda into GRUB automatically
            type = "EF02";
          };
          root = {
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
        };
      };
    };
  };
}
