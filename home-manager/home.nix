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
      package = pkgs.emacs-git.overrideAttrs (old: {
        src = pkgs.fetchFromGitHub {
          owner = "emacs-mirror";
          repo = "emacs";
          rev = "6f1e317764d";
          # Can find the sha256 by either passing an empty string and seeing
          # what home-manager switch reports the correct sha256 to be, or
          # running in the CLI something in the form of
          #
          #   nix flake prefetch <source>:<owner>/<repo>/<rev>
          #
          # For example:
          #
          #   nix flake prefetch github:emacs-mirror/emacs/8c411381c69
          sha256 = "sha256-5iUcwwDXbZFNEtkU88rnPs5u5nlVnvr3ByxILfrwpp0=";
        };
        # Additional configure flags
        configureFlags = (old.configureFlags or [ ]) ++ [
          # 2025-04-16: These two flags are necessary for supporting the alpha
          # frame parameter.  See
          # https://github.com/nix-community/emacs-overlay/issues/347#issuecomment-1664726327
          "--with-x-toolkit=no"
          "--with-cairo"
        ];
        # Extra build inputs
        buildInputs = (old.buildInputs or [ ]) ++ [ ];
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
