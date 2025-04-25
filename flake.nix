# Template Nix structure taken from https://github.com/Misterio77/nix-starter-configs
{
  description = "My nix config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixos-wsl.url = "github:nix-community/NixOS-WSL/main";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    vale-nix.url = "github:krisbalintona/vale-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixos-wsl,
      home-manager,
      ...
    }@inputs:
    let
      inherit (self) outputs;
    in
    {
      # * Modules
      # Reusable nixos modules you might want to export
      # These are usually stuff you would upstream into nixpkgs
      nixosModules = import ./modules/nixos;
      # Reusable home-manager modules you might want to export
      # These are usually stuff you would upstream into home-manager
      homeManagerModules = import ./modules/home-manager;

      # * NixOS
      # Available through:
      #   nixos-rebuild --flake .#machine-hostname
      nixosConfigurations = {
        # ** WSL system
        NixOS-WSL = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs outputs; };
          modules = [
            # From
            # https://nix-community.github.io/NixOS-WSL/how-to/nix-flakes.html
            nixos-wsl.nixosModules.default
            {
              system.stateVersion = "24.11";
              # See https://nix-community.github.io/NixOS-WSL/options.html for
              # available NixOS-WSL options.
              wsl = {
                enable = true;
                defaultUser = "krisbalintona";
                startMenuLaunchers = true;
              };
            }
            ./nixos/configuration.nix
          ];
        };
      };

      # * Home-manager
      # Home-manager configuration.  Available through:
      #   home-manager --flake .#my-username@machine-hostname
      homeConfigurations = {
        "krisbalintona@NixOS-WSL" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages.x86_64-linux; # Home-manager requires 'pkgs' instance
          extraSpecialArgs = { inherit inputs outputs; };
          modules = [
            ./home-manager/home.nix
          ];
        };
      };

      # * End
    };
}
