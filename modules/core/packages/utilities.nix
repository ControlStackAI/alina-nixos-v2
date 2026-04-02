{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = with pkgs; [
    ledger-live-desktop
  ];
}
