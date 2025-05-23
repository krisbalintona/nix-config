# * Preamble
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  # * Host name
  networking.hostName = "NixOS-WSL";

  # * Time zone
  # TODO 2025-04-16: I manually set this here because I could not get tzupdate
  # nor automatic-timezoned to work.  The former I'm not sure why; for the
  # latter, there was the issue of Mozilla shutting down their geolocation
  # provider service for geoclue (which automatic-timezoned used by default),
  # but even after changing geoclue to use a working provider, it still didn't
  # work.  I suspect this is only applicable to WSL2.  Find a fix or
  # alternative.
  time.timeZone = "America/Chicago";

  # * Imports
  imports = [ ];

  # * Nix
  nix =
    let
      flakeInputs = lib.filterAttrs (_: lib.isType "flake") inputs;
    in
    {
      settings = {
        experimental-features = "nix-command flakes"; # Enable flakes and 'nix' command
        nix-path = config.nix.nixPath; # Workaround for https://github.com/NixOS/nix/issues/9574
        # Disables the use of the flake registry on GitHub.  Means the system
        # won’t pull from the global registry but means you have to maintain
        # your own, makes it harder to discover new flakes, etc.
        flake-registry = "";
      };
      # Completely disables Nix channels.  Forces package sources to come from
      # flakes, but removes a fallback mechanism.
      channel.enable = false;

      # Syncs system Nix registry and NIX_PATH with flake inputs.  Means that
      # same dependencies are used whether being accessed via flakes or nix-*
      # commands.
      registry = lib.mapAttrs (_: flake: { inherit flake; }) flakeInputs;
      nixPath = lib.mapAttrsToList (n: _: "${n}=flake:${n}") flakeInputs;

      # Garbage collection
      gc = {
        automatic = true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
    };

  # * Nixpkgs
  nixpkgs = {
    config = {
      allowUnfree = true;
    };
    overlays = [ ];
  };

  # * Users
  users.users = {
    krisbalintona = {
      isNormalUser = true;
      openssh.authorizedKeys.keys = [ ];
      extraGroups = [ "wheel" ];
      shell = pkgs.fish;
    };
  };

  # * Environment

  # ** Packages
  environment.systemPackages = with pkgs; [
    # Utilities
    home-manager
    wl-clipboard
    gcc
    gnumake
    pkgconf # Are these two different?
    pkg-config
    git
    openssh
    x11_ssh_askpass
    tree
    ripgrep
    unzip
    xorg.xmodmap
    xdg-utils
    findutils
    mlocate
    wget

    # Wayland
    wayland
    wayland-utils

    # Shell
    fish
    fzf
    atuin
    neovim
    keychain

    # Languages and package managers
    python3Full
    R
    nodejs
    yarn

    # My tools
    syncthing
    emacs
    libreoffice-still
    graphviz
    evince
    firefox
  ];

  # *** Fonts
  fonts = {
    enableDefaultPackages = true;
    fontDir.enable = true; # Flatpak compatibility
    packages = with pkgs; [
      google-fonts
      noto-fonts
      noto-fonts-extra
      overpass
      iosevka
      lato
      liberation_ttf
      open-sans
      roboto
      roboto-mono
      ubuntu-sans
      ubuntu-sans-mono
      jetbrains-mono
      anonymousPro
      fira-code
      fira-code-symbols

      # Symbols for Emacs
      nerd-fonts.symbols-only
      emacs-all-the-icons-fonts

      # Nerd fonts.  We generally prefer nerd-font versions of fonts.
      nerd-fonts.iosevka
      nerd-fonts.iosevka-term
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      nerd-fonts.droid-sans-mono
      nerd-fonts.noto
      nerd-fonts.hack
      nerd-fonts.ubuntu
      nerd-fonts.overpass
      # TODO 2025-05-18: Integrate this into emacs.nix if possible,
      # since these fonts are specifically used there.
      # Nerd-fonts versions of Iosevka variants.  See
      # https://github.com/Iosevka-NerdFont for all available fonts and their
      # respective repositories.  Nix implementation inspired by
      # https://www.reddit.com/r/NixOS/comments/10726vc/installing_fonts_that_arent_in_nixpkgs/
      # and https://github.com/jeslie0/fonts/blob/main/flake.nix.  (Note: the
      # truetype/ subdirectory is conventionally where TTF fonts are held.)
      (pkgs.stdenv.mkDerivation {
        name = "nerd-font.iosevka-aile";
        src = pkgs.fetchFromGitHub {
          owner = "Iosevka-NerdFont";
          repo = "IosevkaAile";
          rev = "main";
          sha256 = "sha256-m0AwTLNAZONHbRG/BXAYZayamG59hYT89/DyY3+edbY=";
        };
        installPhase = ''
          mkdir -p $out/share/fonts/truetype/nerd-fonts-iosevka-aile
          cp -r $src/IosevkaAile/* $out/share/fonts/truetype/nerd-fonts-iosevka-aile
        '';
      })
      (pkgs.stdenv.mkDerivation {
        name = "nerd-font.iosevka-ss11";
        src = pkgs.fetchFromGitHub {
          owner = "Iosevka-NerdFont";
          repo = "IosevkaSS11";
          rev = "main";
          sha256 = "sha256-Dt48F8sFSxSUk2YiWC1Ivfch8OeryCMl9zzussD2SO4=";
        };
        installPhase = ''
          mkdir -p $out/share/fonts/truetype/nerd-fonts-iosevka-ss11
          cp -r $src/IosevkaSS11/* $out/share/fonts/truetype/nerd-fonts-iosevka-ss11
        '';
      })
      (pkgs.stdenv.mkDerivation {
        name = "nerd-font.iosevka-term-ss11";
        src = pkgs.fetchFromGitHub {
          owner = "Iosevka-NerdFont";
          repo = "IosevkaTermSS11";
          rev = "main";
          sha256 = "sha256-bNN7WTgddu8nPN/mdeOfeZPYk2I8Iio0ZSYddaAp0wY=";
        };
        installPhase = ''
          mkdir -p $out/share/fonts/truetype/nerd-fonts-iosevka-term-ss11
          cp -r $src/IosevkaTermSS11/* $out/share/fonts/truetype/nerd-fonts-iosevka-term-ss11
        '';
      })
      (pkgs.stdenv.mkDerivation {
        name = "nerd-font.iosevka-ss04";
        src = pkgs.fetchFromGitHub {
          owner = "Iosevka-NerdFont";
          repo = "IosevkaSS04";
          rev = "main";
          sha256 = "sha256-enquBElBAA21TkWDlupVSCw0r7OQKE05I7aGInrpajA=";
        };
        installPhase = ''
          mkdir -p $out/share/fonts/truetype/nerd-fonts-iosevka-ss04
          cp -r $src/IosevkaSS04/* $out/share/fonts/truetype/nerd-fonts-iosevka-ss04
        '';
      })
      (pkgs.stdenv.mkDerivation {
        name = "nerd-font.iosevka-term-ss04";
        src = pkgs.fetchFromGitHub {
          owner = "Iosevka-NerdFont";
          repo = "IosevkaTermSS04";
          rev = "main";
          sha256 = "sha256-8CNUgALQBxBTbjFkOs0wSrS9WP4wc2ICxRBzBjC2dzE=";
        };
        installPhase = ''
          mkdir -p $out/share/fonts/truetype/nerd-fonts-iosevka-term-ss04
          cp -r $src/IosevkaTermSS04/* $out/share/fonts/truetype/nerd-fonts-iosevka-term-ss04
        '';
      })
    ];
  };

  # ** Variables
  # environment.sessionVariables = {
  environment.variables = {
    NIXOS_OZONE_WL = "1"; # Hint electron apps to use wayland
    EDITOR = "nvim";
    # Explicitly set these since some non-interactively called code (e.g. python
    # libraries) use this instead of the system path
    BROWSER = "firefox";
  };

  # ** XDG
  xdg.mime = {
    enable = true;
    defaultApplications = {
      # Web links
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";
      # Images
      "application/pdf" = "org.gnome.Evince.desktop";
      "image/png" = "org.gnome.Evince.desktop";
    };
  };

  # * Services

  # ** OpenSSH
  # This setups a SSH server.  Very important if you're setting up a headless
  # system.  Feel free to remove if you don't need it.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no"; # Opinionated: forbid root login through SSH.
      PasswordAuthentication = true; # Set to false if I want to use keys only
    };
  };

  # ** Syncthing
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true"; # Don't create default ~/Sync folder
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "127.0.0.1:8385"; # Different one from default (8384)
    user = "krisbalintona";
    group = "users";
    #dataDir = "/home/krisbalintona/.config/syncthing";
    configDir = "/home/krisbalintona/.config/syncthing";
    # Override settings from GUI
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = {
        "G14 2024 Arch WSL2" = {
          id = "OQHSZRW-L2TT7IC-7USSLNU-ST7JYML-J7J6CU3-42P7NCA-WHE7BEL-SASRXA3";
        };
        "OnePlus 7 Pro" = {
          id = "OVGYOBF-JPFQJKE-6CKRY7J-JULRCWK-WSGSA6Y-SQZYLLE-B2OLSDJ-6DRSTQZ";
        };
      };

      folders = {
        "k4vqh-rny7b" = {
          label = "Agenda";
          path = "/home/krisbalintona/Documents/org-database/agenda/";
          devices = [
            "G14 2024 Arch WSL2"
            "OnePlus 7 Pro"
          ];
        };
        "qtuzy-ufufb" = {
          label = "Notes";
          path = "/home/krisbalintona/Documents/org-database/notes";
          devices = [
            "G14 2024 Arch WSL2"
            "OnePlus 7 Pro"
          ];
        };
      };
    };
  };

  # ** Dictd
  services.dictd.enable = true;
  services.dictd.DBs = with pkgs.dictdDBs; [
    # 2025-04-14: Don't know of any other good English databases
    wordnet
    wiktionary
  ];

  # ** Locate
  services.locate.enable = true;

  # * Programs

  # ** Fish
  programs.fish.enable = true; # Need this for settings my user's default shell to fish

  # ** Firefox
  programs.firefox.enable = true;

  # ** Evince
  programs.evince.enable = true;

  # ** FZF
  programs.fzf = {
    keybindings = true;
    fuzzyCompletion = false;
  };

  # * End
}
