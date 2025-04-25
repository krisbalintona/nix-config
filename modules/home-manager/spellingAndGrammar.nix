{
  inputs,
  lib,
  config,
  pkgs,
  ...
}:
let
  # Vale config with vale overlay.  We define krisbValeWithConfig so that in
  # home.file we can reference the .vale.ini file created, symlinking it to a
  # location vale recognizes as a config path (e.g. ~/.config/vale/.vale.ini).
  krisbValeWithConfig = (
    pkgs.valeWithConfig {
      packages =
        # Install many packages, even if I don't use all of them. I can enable
        # specific rules to pick and choose what I want from these "presets".
        # Some of these are packages with rules while other are just config
        # files; see https://vale.sh/explorer and
        # https://github.com/topics/vale-linter-stylefor a complete list.  Also,
        # I think the order matters: later packages in this list override rules
        # from earlier ones (see
        # https://vale.sh/docs/topics/packages/#package-ordering-and-overrides).
        #
        # See
        # https://github.com/icewind1991/vale-nix/blob/main/styles/builder.nix
        # for how to build rules from external repos
        styles: with styles; [
          # NOTE 2024-10-05: The proselint style is just a vale-style
          # declaration of proselint's rules, not using proselint the
          # binary. Thus, it doesn't use proselint's config file
          proselint
          write-good
          joblint
          alex
          # TODO 2025-04-24: I used to have Hugo's config installed (which
          # applies to .md files), but I don't know how to do this with Nix.
          # See PR to vale-nix overlay here:
          # https://github.com/icewind1991/vale-nix/issues/1
          # Hugo
          (builder rec {
            # HACK 2025-04-24: I specify name to be the relative file path to
            # the directory to the rules, but only because the build
            # instructions use the name for the path.  This abuses that fact.
            # Name is used for other (non-functional) purposes.
            name = ".vale/styles/RedHat/";
            owner = "redhat-documentation";
            repo = "vale-at-red-hat";
            version = "597";
            rev = "v${version}";
            sha256 = "sha256-Y5TshFG8EfcsmhEqTljxkxb2hRmfem+0njQDa/mUhmw=";
          })
          microsoft
          google
          # readability
          # Other packages
          # Openly: try to emulate Grammarly
          (builder rec {
            name = "Openly";
            owner = "ChrisChinchilla";
            repo = "Openly";
            version = "0.4.4";
            rev = "v${version}";
            sha256 = "sha256-Mq0+NRmgDQ7GARJjHvWxIlXX3oIzzPJqGWNf1wRWwuM=";
          })
        ];
      vocab = {
        accept = [ ];
        reject = [ ];
      };
      minAlertLevel = "suggestion"; # Can be suggestion, warning, or error
      formatOptions = {
        "*" = {
          # These must be names of the styles installed.  Be careful of
          # capitalization.  You can ensure the capitalization is correct by
          # looking at the Packages= line in the config file the overlay
          # generates (which you can see with vale ls-config).
          basedOnStyles = [
            "Vale"
            "proselint"
            "Openly"
            "krisb-custom"
          ];
          "Openly.Spelling" = false;
          "Vale.Spelling" = false;
          "proselint.Very" = "suggestion";
          "proselint.But" = false;
          "proselint.GenderBias" = "warning";
          "proselint.Hyperbole" = "warning";
          "write-good.Passive" = "suggestion";
          "Google.LyHyphens" = true;
          "Google.OxfordComma" = true;
          "Google.Periods" = true;
          "Google.Units" = true;
          "Google.Ordinal" = true;
          "Microsoft.Wordiness" = true;
          "Microsoft.Ordinal" = true;
          "Microsoft.Negative" = true;
          "Microsoft.Dashes" = true;
          "RedHat.Abbreviations" = true;
          "RedHat.Using" = true;
        };
        "*.org" = {
          "Openly.Titles" = false;
          "Openly.E-Prime" = false;
          "proselint.Annotations" = false;
          "proselint.Very" = false;
        };
      };
    }
  );
in
{
  nixpkgs = {
    overlays = [
      # Vale
      inputs.vale-nix.overlays.default
    ];
  };

  home.packages = with pkgs; [
    # NOTE 2025-04-12: It seems all the dicts (but not necessarily the
    # dictionaries for the language(s) I use) need to be installed for jinx to
    # recognize the language?  A quirk of the .c module...?
    enchant
    aspellDicts.en
    aspellDicts.la
    nuspell
    hunspell
    hunspellDicts.en_US # Nuspell relies on hunspell dictionaries; need this otherwise Enchant falls back on aspell
    # Read
    # https://medium.com/valelint/introducing-vale-an-nlp-powered-linter-for-prose-63c4de31be00
    # for an explanation of Vale and how it focuses on correcting style rather
    # than grammar
    krisbValeWithConfig
    harper
  ];

  home.file = {
    "${config.xdg.configHome}/enchant/enchant.ordering".source = config/enchant/enchant.ordering;

    "${config.xdg.configHome}/vale/.vale.ini".source = "${krisbValeWithConfig}/.vale.ini";
    "${config.xdg.dataHome}/vale/styles/krisb-custom" = {
      source = config/vale/krisb-custom;
      recursive = true;
    };
  };

  # Symlink Enchant directories.  We do it manually rather than with home.file
  # because Jinx, in Emacs, fails to write to the symlinked files.
  # Additionally, even if they were successfully written, those files are
  # containerized within nix store generations -- they changes would not
  # persist.  Therefore, this is the solution I've found.
  home.activation.linkEnchantDictionaries = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    echo "Linking .dic and .exc files to ${config.xdg.configHome}/enchant/..."
    src="${config/enchant}"
    dest="${config.xdg.configHome}/enchant"
    mkdir -p "$dest"
    for file in "$src"/*.dic "$src"/*.exc; do
      [ -e "$file" ] || continue
      ln -sf "$file" "$dest/$(basename "$file")"
    done'';
}
