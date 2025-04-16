# * Preamble
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
{
  programs.home-manager.enable = true;

  home = {
    username = "krisbalintona";
    homeDirectory = "/home/krisbalintona";
  };

  # Nicely reload system units when changing configs.  See
  # https://home-manager-options.extranix.com/?query=systemd.user.startServices&release=master
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "24.05";

  # * Imports
  imports = [ ];

  # * Nixpkgs
  nixpkgs = {
    overlays = [
      (import (
        builtins.fetchTarball {
          url = "https://github.com/nix-community/emacs-overlay/archive/master.tar.gz";
          sha256 = "05giy64csmv11p12sd6rcfdgfd1yd24w0amfmxm9dhxwizgs2c0g";
        }
      ))
    ];
    config = {
      allowUnfree = true;
    };
  };

  # * Packages
  home.packages = with pkgs; [
    ## Emacs stuff
    jujutsu
    # NOTE 2025-04-12: It seems all the dicts (but not necessarily the
    # dictionaries for the language(s) I use) need to be installed for jinx to
    # recognize the language?  A quirk of the .c module...?
    enchant
    aspellDicts.en
    nuspell
    hunspell
    hunspellDicts.en_US-large
    vale
    harper
    yt-dlp
    hugo
    mermaid-cli
    msmtp
    notmuch
    lieer
    texlivePackages.latexmk
    texliveFull # To cover every case
    # Coding
    go
    emacs-lsp-booster
    nixfmt-rfc-style
    nodePackages_latest.prettier
    nil # Nix LSP server
  ];

  # * Files
  # The primary way to manage plain files
  home.file = {
    ".config/jj/config.toml" = {
      source = config/jj/config.toml;
    };

    ".config/enchant" = {
      source = config/enchant;
      recursive = true;
    };

    ".config/atuin/config.toml" = {
      source = config/atuin/config.toml;
      force = true; # Overwrite the default one that's automatically generated
    };
  };

  # * Environment

  # ** Variables
  home.sessionVariables = {
    EDITOR = "nvim";
  };

  # * Programs
  programs.git = {
    enable = true;
    userEmail = "krisbalintona@gmail.com";
    userName = "Kristoffer Balintona";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    forwardAgent = true;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      atuin init fish | source
    '';
    plugins = with pkgs; [
      {
        name = "grc";
        src = fishPlugins.grc.src;
      }
      {
        name = "z";
        src = fishPlugins.z.src;
      }
      {
        name = "hydro";
        src = fishPlugins.hydro.src;
      }
      {
        name = "fzf-fish";
        src = fishPlugins.fzf-fish.src;
      }
    ];
  };

  services.emacs.package = pkgs.emacsGit; # Use emacs-overlay for the emacs daemon
  programs.emacs = {
    enable = true;
    package = pkgs.emacsWithPackagesFromUsePackage {
      # See https://jeffkreeftmeijer.com/emacs-configuration/#installation for
      # examples of the various ways to configuration how Emacs can be
      # configured and installed with emacs-overlay.
      #
      # For the source code emacs-overlay uses for its various emacs packages,
      # see
      # https://github.com/nix-community/emacs-overlay/blob/master/overlays/emacs.nix.
      # To see the options th nixpkgs emacs has (which emacs-overlay uses
      # internally; might be useful for creating my own builds), see
      # https://github.com/NixOS/nixpkgs/blob/nixos-24.11/pkgs/applications/editors/emacs/make-emacs.nix.
      package = pkgs.emacs-git.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          owner = "emacs-mirror";
          repo = "emacs";
          rev = "6f1e317764d";
          # Can find the sha256 by either passing an empty string and seeing
          # what home-manager switch reports the correct sha256 to be, or
          # running in the CLI something in the form of
          #   nix flake prefetch <source>:<owner>/<repo>/<rev>
          # For example:
          #   nix flake prefetch github:emacs-mirror/emacs/8c411381c69
          sha256 = "sha256-5iUcwwDXbZFNEtkU88rnPs5u5nlVnvr3ByxILfrwpp0=";
        };
        # C compile flags
        NIX_CFLAGS_COMPILE = (old.NIX_CFLAGS_COMPILE or "") + " -O2 -march=native";
        # Additional configure flags
        configureFlags = (old.configureFlags or [ ]) ++ [
          "--with-native-compilation"
          "--with-imagemagick"
          "--with-cairo"
          # For supporting the alpha frame parameter.  See also
          # https://github.com/nix-community/emacs-overlay/issues/347#issuecomment-1664726327.
          # I am not sure if this is the only solution; perhaps the lucid
          # x-toolkit would work (perhaps alongside other flags...)
          "--with-x-toolkit=gtk3"
        ];
        # Extra build inputs
        buildInputs = (old.buildInputs or [ ]) ++ [
          pkgs.imagemagick # For --with-imagemagick
          pkgs.gtk3 # For --with-x-toolkit=gtk3
        ];
      });

      config = "/home/krisbalintona/.emacs.d/emacs-config.org";
      defaultInitFile = false;
      alwaysEnsure = true;
      alwaysTangle = false;

      extraEmacsPackages = epkgs: [
        epkgs.jinx # Necessary to correctly compile its C module
        epkgs.denote
      ];

      # If you want to override packages in the Emacs package set:
      # override = final: prev: { };
    };
  };

  # * End
}
