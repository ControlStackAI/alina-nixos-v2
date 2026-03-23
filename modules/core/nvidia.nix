{
  config,
  pkgs,
  lib,
  ...
}: {
  # NVIDIA RTX A500 Laptop GPU (Ampere GA107GLM) — hybrid Intel + NVIDIA
  services.xserver.videoDrivers = ["nvidia"];

  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # proprietary driver — more stable for RTX A500
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true; # provides `nvidia-offload` wrapper
      };
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  # Ensure nvidia-smi, lspci, and CUDA tools are available
  environment.systemPackages = with pkgs; [
    pciutils
    nvtopPackages.nvidia
  ];

  # Enable OpenGL / graphics hardware acceleration
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver # Intel iGPU (VA-API)
    ];
  };
}
