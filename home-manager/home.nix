# * Preamble
{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  # Helper function to create maildir structure for a given account necessary
  # for lieer to sync
  maildirSetupActivation =
    accountName:
    let
      pathSegments = [
        # This is an absolute path, like: /home/krisbalintona/Documents/emails
        "${config.accounts.email.maildirBasePath}"
        # This is a relative path, like: personal
        "${config.accounts.email.accounts.${accountName}.maildir.path}"
      ];
      fullPath = lib.concatStringsSep "/" pathSegments;
      mailPath = "${fullPath}/mail";
      credentialsPath = "${fullPath}/.credentials.gmailieer.json";
    in
    # Lieer expects the mail/cur, mail/new, and mail/tmp subdirectories in the
    # path where the .gmailieer.json file (created by gmi) is found.
    # Additionally, if the credentials file is non-existent, we create it via
    # gmi auth.
    #
    # NOTE 2025-04-16: if there is trouble opening the browser tab for
    # authentication, like in NixOS-WSL, then look at the CLI output: I can
    # manually open the outputted link.
    #
    # TODO 2025-04-16: Currently, we have a hard time on initial installs;
    # there, we have to do some imperative commands.  Namely, we might have to
    # gmi auth and gmi sync manually (then restart the services).  Not sure what
    # can be done about that... Regarding the syncing, I might be able to save
    # the .credentials.gmaileer.json to avoid re-authenticating.
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ ! -d "${mailPath}" ]; then
        echo "Creating lieer maildir for account \"${accountName}\" exists at ${fullPath}..."
        mkdir -p ${mailPath}/{cur,new,tmp}
      fi
      if [ ! -f "${credentialsPath}" ]; then
        echo "Opening browser for lieer Google authentication..."
        (cd ${fullPath} && ${pkgs.lieer}/bin/gmi auth)
      fi
    '';
in
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
    grc # For fishPlugins.grc
  ];

  # * Files
  # The primary way to manage plain files
  home.file = {
    ".config/enchant" = {
      source = config/enchant;
      recursive = true;
    };
  };

  # * Environment

  # ** Variables
  home.sessionVariables = { };

  # * Programs

  # ** Git
  programs.git = {
    enable = true;
    userEmail = "krisbalintona@gmail.com";
    userName = "Kristoffer Balintona";
    extraConfig = {
      init.defaultBranch = "main";
    };
  };

  # ** Ssh
  programs.ssh = {
    enable = true;
    addKeysToAgent = "yes";
    forwardAgent = true;
  };

  # ** Atuin
  programs.atuin = {
    enable = true;
    enableFishIntegration = true;
    flags = [ "--disable-up-arrow" ];
    settings = {
      dialect = "us";
      auto_sync = true;
      update_check = true;
      sync_frequency = "0m";
      ctrl_n_shortcuts = true;
      history_format = "{time}\t{command} - {directory}$\t{host}";
      enter_accept = false;
      common_prefix = [ "sudo" ];
      scroll_exits = false;
      records = true;
    };
    daemon = {
      enable = false; # I prefer sync_frequency = "0m"
    };
  };

  # ** Fish
  programs.fish = {
    enable = true;
    shellInit = ''
      # Sponge (automatically clean history)
      if status is-interactive
        set --global sponge_purge_only_on_exit true
      end
    '';
    plugins = with pkgs.fishPlugins; [
      {
        name = "grc"; # Command colorizers
        src = grc.src;
      }
      {
        name = "z"; # Frecency directory jumping
        src = z.src;
      }
      {
        name = "hydro"; # Simple prompt
        src = hydro.src;
      }
    ];
  };

  # ** Jujutsu
  # TODO 2025-04-17: Not sure if I still need something like the following for
  # dynamic completions with fish:
  #   if test -e /usr/bin/jj
  #     jj util completion fish | source
  #   end
  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "Kristoffer Balintona";
        email = "krisbalintona@gmail.com";
      };
      ui = {
        editor = "nvim";
        conflict-marker-style = "git";
      };
    };
  };

  # ** Emacs
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

  # ** Email (lieer and notmuch)
  programs.lieer.enable = true;
  services.lieer.enable = true;
  programs.notmuch = {
    enable = true;
    search = {
      excludeTags = [ "deleted" ];
    };
    hooks = {
      preNew = builtins.readFile ./config/notmuch/pre-new;
      postNew = builtins.readFile ./config/notmuch/post-new;
    };
  };

  accounts.email.maildirBasePath = "Documents/emails";
  accounts.email.accounts."personal" = {
    primary = true;
    realName = "Kristoffer Balintona";
    address = "krisbalintona@gmail.com";
    flavor = "gmail.com";
    maildir.path = "personal"; # Relative to accounts.email.maildirBasePath
    # NOTE: I don't need these for lieer.
    # Relative to accounts.email.accounts.<name>.maildir.path
    # folders = {
    #   inbox = "inbox";
    #   trash = "trash";
    #   drafts = "drafts";
    #   sent = "sent";
    # };
    lieer = {
      enable = true;
      # Creates lieer-<account_name>.service systemd user services
      sync = {
        enable = true;
        frequency = "*:0/4"; # Sync every 4 minutes
      };
      settings = {
        ignore_empty_history = true;
      };
    };
    notmuch.enable = true;
  };

  accounts.email.accounts."uni" = {
    primary = false;
    realName = "Kristoffer Balintona";
    address = "kristoffer_balintona@alumni.brown.edu";
    flavor = "gmail.com";
    maildir.path = "uni"; # Relative to accounts.email.maildirBasePath
    # NOTE: I don't need these for lieer.
    # Relative to accounts.email.accounts.<name>.maildir.path
    # folders = {
    #   inbox = "inbox";
    #   trash = "trash";
    #   drafts = "drafts";
    #   sent = "sent";
    # };
    lieer = {
      enable = true;
      # Creates lieer-<account_name>.service systemd user services
      sync = {
        enable = true;
        frequency = "*:0/4"; # Sync every 4 minutes
      };
      settings = {
        ignore_empty_history = true;
      };
    };
    notmuch.enable = true;
  };

  # Create lieer maildir structure for each account
  home.activation = lib.mkMerge (
    map (name: {
      "createLieerMaildirActivation-${name}" = maildirSetupActivation name;
    }) (lib.attrNames config.accounts.email.accounts)
  );

  # * End
}
