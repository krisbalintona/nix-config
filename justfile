# * Variables

# Use bash for shell commands
set shell := ["bash", "-c"]

# * Common commands

# List all the just commands
default:
    @just --list

# * Home-manager commands

# Rebuild home-manager and switch to that generation
home-manager:
    home-manager switch --max-jobs 14 --flake "./#krisbalintona@NixOS-WSL" --show-trace

# * NixOS commands

# Rebuild NixOS and switch to that generation
nixos:
    sudo nixos-rebuild switch --max-jobs 14 --flake "./#NixOS-WSL" --show-trace
