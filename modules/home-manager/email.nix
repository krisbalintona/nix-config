{
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
      pathSegments = with config.accounts.email; [
        # This is an absolute path, like: /home/krisbalintona/Documents/emails
        "${maildirBasePath}"
        # This is a relative path, like: personal
        "${accounts.${accountName}.maildir.path}"
      ];
      accountPath = lib.concatStringsSep "/" pathSegments;
      mailPath = "${accountPath}/mail";
      credentialsPath = "${accountPath}/.credentials.gmailieer.json";
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
        echo "Creating lieer maildir for account \"${accountName}\" exists at ${accountPath}..."
        mkdir -p ${mailPath}/{cur,new,tmp}
      fi
      if [ ! -f "${credentialsPath}" ]; then
        echo "Opening browser for lieer Google authentication..."
        (cd ${accountPath} && ${pkgs.lieer}/bin/gmi auth)
      fi
    '';
in
{
  home.packages = with pkgs; [
    lieer
    notmuch
  ];

  programs.lieer.enable = true;
  services.lieer.enable = true;
  programs.notmuch = {
    enable = true;
    search = {
      excludeTags = [ "deleted" ];
    };
    hooks = {
      preNew = ''
        #!/bin/bash

        # pre-new --- Notmuch rules that run after notmuch new

        # Actually delete emails with "deleted" tag. Taken from
        # https://wiki.archlinux.org/title/Notmuch#Permanently_delete_emails.
        notmuch search --output=files --format=text0 tag:deleted | ${pkgs.findutils}/bin/xargs -r0 rm
      '';
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

  # Ensure the lieer maildir structure for each account exists
  home.activation = lib.mkMerge (
    # TODO 2025-04-17: Not sure if this is called before or after the first
    # invocation of the lieer services.  If it is after, then I would need to
    # restart those services (after these directories are created).
    map (name: {
      "createLieerMaildirActivation-${name}" = maildirSetupActivation name;
    }) (lib.attrNames config.accounts.email.accounts)
  );

  systemd.user.services =
    # Ensure notmuch new is called after every lieer sync
    # systemd.user.services =
    let
      lieerAccounts = lib.filter (a: a.lieer.enable && a.lieer.sync.enable) (
        lib.attrValues config.accounts.email.accounts
      );
      lieerAccountNames = map (a: a.name) lieerAccounts;
      # Modify these services
      modifyAccountService =
        accountName:
        let
          # 2025-04-17: The way lieer integration names its services (without .service suffix)
          serviceName = "lieer-" + accountName;
          pathSegments = with config.accounts.email; [
            # This is an absolute path, like: /home/krisbalintona/Documents/emails
            "${maildirBasePath}"
            # This is a relative path, like: personal
            "${accounts.${accountName}.maildir.path}"
          ];
          accountPath = lib.concatStringsSep "/" pathSegments;
        in
        {
          name = serviceName;
          value.Service = {
            # ExecStart cannot be multi-line
            ExecStart = pkgs.lib.mkForce ''${pkgs.bash}/bin/bash -c "if ! ${config.programs.lieer.package}/bin/gmi sync; then echo 'Sync failed! Salvaging state...'; cp ${accountPath}/.state.gmailieer.json{.bak,}; fi"'';
            ExecStartPost = "${pkgs.notmuch}/bin/notmuch new";
          };
        };
    in
    lib.listToAttrs (map modifyAccountService lieerAccountNames);
}
