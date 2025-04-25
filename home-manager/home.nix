# * Preamble
{
  inputs,
  outputs,
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

  # * Nixpkgs
  nixpkgs = {
    overlays = [ ];
    config = {
      allowUnfree = true;
    };
  };

  # * Packages
  home.packages = with pkgs; [
    zotero
    nix-search-tv # Fuzzy search for NixOS packages and their content
    # 2025-04-21: As recommended in
    # https://github.com/3timeslazy/nix-search-tv?tab=readme-ov-file#fzf, we can
    # use a custom script (provided by nix-search-tv) to integrate conveniently
    # with fzf so provide commands like opening a homepage, package's source,
    # and more.  For now, this is a bespoke script, so we pull directly from the
    # GitHub in case any future updates are given.  We name this script "nts".
    (writeShellScriptBin "nts" (
      builtins.readFile (
        pkgs.fetchFromGitHub {
          owner = "3timeslazy";
          repo = "nix-search-tv";
          rev = "main";
          sha256 = "sha256-fU81GVVgqxXG1xdsID2WztzdY7hNxYDBZObaNpLeMEg=";
        }
        + "/nixpkgs.sh"
      )
    ))
    moar
  ];

  # * Files
  # The primary way to manage plain files
  home.file = { };

  # * Environment

  # ** Variables
  home.sessionVariables = {
    ## FZF settings
    # Preview file contents using bat.  Taken from
    # https://github.com/junegunn/fzf?tab=readme-ov-file#key-bindings-for-command-line
    FZF_CTRL_T_OPTS = ''
      --walker-skip .git,node_modules,target
      --preview '${lib.getExe pkgs.bat} -n --color=always {}'
      --bind 'ctrl-/:change-preview-window(down|hidden|)'
    '';
    # Print tree structure in the preview window.  Taken from
    # https://github.com/junegunn/fzf?tab=readme-ov-file#key-bindings-for-command-line
    FZF_ALT_C_OPTS = ''
      --walker-skip .git,node_modules,target
      --preview '${lib.getExe pkgs.tree} -C {}'
    '';

    # Use moar as a pager
    MOAR = "--style tokyonight-moon --statusbar inverse --terminal-fg"; # Settings
    PAGER = "${lib.getExe pkgs.moar}";
  };

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

  # ** Keychain
  programs.keychain = {
    enable = true;
    enableFishIntegration = true;
    keys = [ "id_ed25519" ];
    inheritType = "any-once";
    extraFlags = [ "--quiet" ];
  };

  # ** FZF
  programs.fzf = {
    enableFishIntegration = true;
    enableBashIntegration = true;
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
      # 2025-04-17: Uses its own fish prompt that overrides the fish_vcs_prompt
      # I define below.  Hydro's is too complicated to override to use jj, so
      # I'll try disabling the prompt altogether for now.  Or until the jj
      # integration upstream is released in a stable version.
      # {
      #   name = "hydro"; # Simple prompt
      #   src = hydro.src;
      # }
      {
        name = "bass"; # Robust way to run bash commands in fish
        src = bass.src;
      }

      {
        name = "fish-abbreviation-tips "; # Give reminders for abbreviations and aliases I've defined
        src = pkgs.fetchFromGitHub {
          owner = "gazorby";
          repo = "fish-abbreviation-tips";
          rev = "master";
          sha256 = "sha256-F1t81VliD+v6WEWqj1c1ehFBXzqLyumx5vV46s/FZRU=";
        };
      }
    ];
    # TODO 2025-04-17: Currently, on the master branch of fish, jj is
    # integrated.  However, the current verion of fish, 4.0.1, does not include
    # it.  Once it is, I can safely remove the fish_jj_prompt function and
    # fish_vcs_prompt function override below.
    functions = {
      # 2025-04-17: Simple prompt that conveys key information.  Taken from
      # https://github.com/strega-nil/dotfiles/blob/02582a890981040da09d89edc1b4f85cd4fa03df/fish/functions/fish_jj_prompt.fish,
      # which is one of the prompts suggested in
      # https://github.com/jj-vcs/jj/wiki/Fish-shell#prompt.
      # make sure jj is installed
      fish_jj_prompt = {
        description = "VCS segment for JJ.";
        body = ''
          if ! command -sq jj
            return 1
          end
          # check if we're in a jj repo
          if ! jj root --quiet &>/dev/null
            return 1
          end

          if test -n "$__fish_jj_prompt_bookmark_revset"
            set prompt_bookmark_revset "$__fish_jj_prompt_bookmark_revset"
          else
            set prompt_bookmark_revset "@ | @-"
          end

          set current_head (jj log --color=always --no-graph \
            -r "@" -T "change_id.shortest()")
          set current_branch (jj log --color=always --no-graph \
            -r "latest(($prompt_bookmark_revset) & bookmarks())" \
            -T "bookmarks.join(' ')")
          if test -n "$current_branch"
            echo " ($current_head|$current_branch)"
          else
            echo " ($current_head)"
          end
        '';
      };
      # Add fish_jj_prompt to the list of supported VCS by the vanilla fish
      # prompt.
      fish_vcs_prompt = {
        description = "Print all vcs prompts";
        body = ''
          fish_jj_prompt $argv
          or fish_git_prompt $argv
          or fish_hg_prompt $argv
          or fish_fossil_prompt $argv
        '';
      };
    };
    shellAbbrs = {
      m = "moar";
    };
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

  # * Imports
  imports = with outputs.homeManagerModules; [
    email
    spellingAndGrammar
    emacs
  ];

  # * End
}
