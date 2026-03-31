{
  pkgs,
  lib,
  ...
}: let
  # Add new packages here.
  # Keep this file as the single obvious place to extend your user environment.
  fonts = [
    # Fonts (Ghostty config expects this font family)
    pkgs."nerd-fonts"."jetbrains-mono"
  ];

  cli = with pkgs; [
    # Modern replacements for common commands
    eza # Modern replacement for ls
    bat # Modern replacement for cat
    ripgrep # Modern replacement for grep (rg)
    fd # Modern replacement for find
    fzf # Fuzzy finder
    zoxide # Smart directory jumper (z command)

    # Additional useful tools
    htop # Process monitor
    btop # Process monitor (TUI)
    tree # Directory tree viewer
    wget # File downloader
    curl # HTTP client
    jq # JSON processor

    # System utilities
    fastfetch # System info (fast)
    zip # Archive tool
    unzip # Archive tool

    # Nix + direnv integration
    nix-direnv
  ];

  notifications = with pkgs; [
    libnotify # provides notify-send
    swaynotificationcenter # swaync + swaync-client
  ];

  desktop = with pkgs; [
    hyprlock
    hyprpaper

    # Overlay tools / launchers
    wofi

    # Desktop apps referenced by Hyprland config / session defaults
    vivaldi
    vivaldi-ffmpeg-codecs
    widevine-cdm
    kdePackages.dolphin
    slack

    # Hyprland keybind dependencies
    brightnessctl
    playerctl

    # Wayland clipboard + portals (screen sharing / file pickers)
    wl-clipboard
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk

    # Polkit agent (autostarted by Hyprland)
    lxqt.lxqt-policykit

    # Remote Desktop
    anydesk
  ];

  dev = with pkgs; [
    git # Version control
    gh # GitHub CLI
    delta # Git diff pager

    # Terminals
    ghostty
    kitty

    # Shell/dev workflow
    tmux
    zellij
    just
    yazi

    # Language/tooling
    nodejs
    python312
    python312Packages.pip
    python312Packages.virtualenv
    python312Packages.setuptools

    luarocks
    lua-language-server

    nodePackages.prettier
    nodePackages.eslint_d

    yq-go
  ];

  cloud = with pkgs; [
    awscli2
    google-cloud-sdk
    azure-cli
  ];

  k8s = with pkgs; [
    # Kubernetes/Helm tooling
    kubectl
    kubernetes-helm
    k9s
    kubectx
    kustomize
    stern

    # K8s/platform ops tooling
    argocd
    flux
    cilium-cli
    kubelogin-oidc
    talosctl
  ];

  warpWayland = pkgs.writeShellScriptBin "warp-wayland" ''
    #!/usr/bin/env bash
    set -euo pipefail

    # Prefer Wayland for Warp (winit)
    export WINIT_UNIX_BACKEND=wayland

    # Also help other toolkits if Warp spawns anything (harmless if unused)
    export QT_QPA_PLATFORM=wayland
    export GDK_BACKEND=wayland
    export ELECTRON_OZONE_PLATFORM_HINT=wayland

    exec warp-terminal "$@"
  '';

  matlabXwayland = pkgs.writeShellScriptBin "matlab-xwayland" ''
    #!/usr/bin/env bash
    set -euo pipefail

    usage() {
      cat <<'USAGE'
    Usage: matlab-xwayland [options] [--] [matlab args...]

    Runs MATLAB under XWayland/X11 (forces X11 Qt backend) and selects a MATLAB
    release installed under /opt/MATLAB.

    Options:
      --list                 List detected releases (e.g. R2024b, R2025b)
      --release <RYYYYa|b>   Launch a specific release (e.g. --release R2025b)
      --latest               Launch the newest detected release (default)
      --cmd <path>           Launch a specific matlab binary (escape hatch)
      -h, --help             Show this help

    Notes:
      - If you don't pass a UI mode flag, we default to -desktop so launching
        from wofi reliably opens the GUI (no controlling TTY).
      - To force non-GUI mode, pass -batch, -nodisplay, or -nodesktop.
    USAGE
    }

    WANT_LIST=0
    RELEASE=""
    MATLAB_CMD="''${MATLAB_CMD:-}"
    EXTRA_ARGS=()

    while [ "$#" -gt 0 ]; do
      case "$1" in
        -h|--help)
          usage
          exit 0
          ;;
        --list)
          WANT_LIST=1
          shift
          ;;
        --latest)
          RELEASE=""
          shift
          ;;
        --release)
          RELEASE="''${2-}"
          if [ -z "$RELEASE" ]; then
            echo "[matlab-xwayland] ERROR: --release requires a value (e.g. R2025b)" >&2
            exit 2
          fi
          shift 2
          ;;
        --cmd)
          MATLAB_CMD="''${2-}"
          if [ -z "$MATLAB_CMD" ]; then
            echo "[matlab-xwayland] ERROR: --cmd requires a path" >&2
            exit 2
          fi
          shift 2
          ;;
        --)
          shift
          EXTRA_ARGS+=("$@")
          break
          ;;
        *)
          EXTRA_ARGS+=("$1")
          shift
          ;;
      esac
    done

    # Detect installed releases under /opt/MATLAB
    shopt -s nullglob
    rel_dirs=(/opt/MATLAB/R[0-9][0-9][0-9][0-9][ab])
    rels=()
    for d in "''${rel_dirs[@]}"; do
      rels+=("$(basename "$d")")
    done

    if [ "''${#rels[@]}" -gt 0 ]; then
      IFS=$'\n' rels_sorted=($(printf '%s\n' "''${rels[@]}" | sort -u))
      unset IFS
    else
      rels_sorted=()
    fi

    if [ "$WANT_LIST" -eq 1 ]; then
      printf '%s\n' "''${rels_sorted[@]}"
      exit 0
    fi

    # Choose which matlab binary to run
    if [ -z "$MATLAB_CMD" ]; then
      if [ -n "$RELEASE" ]; then
        case "$RELEASE" in
          R*) ;;
          *) RELEASE="R$RELEASE" ;;
        esac
        cand="/opt/MATLAB/$RELEASE/bin/matlab"
        if [ ! -x "$cand" ]; then
          echo "[matlab-xwayland] ERROR: requested release not found: $RELEASE" >&2
          echo "[matlab-xwayland] Available releases:" >&2
          printf '  %s\n' "''${rels_sorted[@]}" >&2
          exit 127
        fi
        MATLAB_CMD="$cand"
      elif [ "''${#rels_sorted[@]}" -gt 0 ]; then
        last_idx=$((''${#rels_sorted[@]} - 1))
        RELEASE="''${rels_sorted[$last_idx]}"
        MATLAB_CMD="/opt/MATLAB/$RELEASE/bin/matlab"
      elif command -v matlab >/dev/null 2>&1; then
        MATLAB_CMD="matlab"
      else
        echo "[matlab-xwayland] ERROR: no MATLAB releases found under /opt/MATLAB and matlab not in PATH" >&2
        exit 127
      fi
    fi

    # Force X11/XWayland backends for MATLAB/Simulink under Hyprland.
    # Your Hyprland session sets Wayland-preference env globally; this wrapper overrides it.
    export QT_QPA_PLATFORM=xcb
    export GDK_BACKEND=x11
    export CLUTTER_BACKEND=x11

    # Java/AWT hint for wlroots compositors / non-reparenting WMs
    export _JAVA_AWT_WM_NONREPARENTING=1

    # Prevent toolkits from auto-selecting Wayland
    unset WAYLAND_DISPLAY

    # If no UI mode flag is provided, default to -desktop (needed for launcher execution).
    has_mode=0
    for a in "''${EXTRA_ARGS[@]}"; do
      case "$a" in
        -desktop|-nodesktop|-nodisplay|-batch)
          has_mode=1
          ;;
      esac
    done
    if [ "$has_mode" -eq 0 ]; then
      EXTRA_ARGS=(-desktop "''${EXTRA_ARGS[@]}")
    fi

    exec "$MATLAB_CMD" "''${EXTRA_ARGS[@]}"
  '';

  matlabXwaylandPick = pkgs.writeShellScriptBin "matlab-xwayland-pick" ''
    #!/usr/bin/env bash
    set -euo pipefail

    releases="$(matlab-xwayland --list)"
    if [ -z "$releases" ]; then
      echo "[matlab-xwayland-pick] ERROR: no MATLAB releases found under /opt/MATLAB" >&2
      exit 1
    fi

    if ! command -v wofi >/dev/null 2>&1; then
      echo "[matlab-xwayland-pick] ERROR: wofi not found in PATH" >&2
      printf '%s\n' "$releases" >&2
      exit 1
    fi

    choice="$(printf '%s\n' "$releases" | wofi --dmenu --prompt 'MATLAB release')"
    [ -z "$choice" ] && exit 0

    exec matlab-xwayland --release "$choice" -desktop
  '';

  all = fonts ++ cli ++ notifications ++ desktop ++ dev ++ k8s ++ [warpWayland matlabXwayland matlabXwaylandPick];
in {
  # Ensure user-installed fonts are discoverable
  fonts.fontconfig.enable = true;

  home.packages = lib.lists.unique all;
}
