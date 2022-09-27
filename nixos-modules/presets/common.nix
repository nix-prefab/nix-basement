{ config, lib, pkgs, inputs, ... }:
with builtins; with lib; {

  options.basement.presets.common = mkEnableOption "Default settings for any kind of system";

  config = mkIf config.basement.presets.common {

    environment.defaultPackages = with pkgs; mkForce [
      btop
      curl
      file
      git
      inetutils
      killall
      ncdu
      pv
      rsync
      vim
    ];

    i18n.defaultLocale = mkDefault "en_US.UTF-8";
    console.keyMap = mkDefault "us";
    time.timeZone = mkDefault "Europe/Berlin";

    networking = {
      useDHCP = false; # Is deprecated and has to be set to false
      firewall = {
        enable = true;
        allowPing = true;
      };
    };

    users = rec {
      defaultUserShell = pkgs.zsh;
      mutableUsers = !(config.secrets ? "root.password");
      users.root.passwordFile = mkIf (!mutableUsers) config.secrets."root.password";
    };
    programs.zsh = {
      enable = true;
      enableCompletion = true;
      autosuggestions.enable = true;
      autosuggestions.async = true;
      syntaxHighlighting.enable = true;
      promptInit = ''
        autoload -U colors && colors

        if [[ $UID -eq 0 ]]; then
          export PROMPT="%{$fg[red]%}[%n@%m:%1~]%(#.#.$)%{$reset_color%} "
        else
          export PROMPT="%{$fg[green]%}[%n@%m:%1~]%(#.#.$)%{$reset_color%} "
        fi

        export RPROMPT=""
      '';
    };

    boot.kernel.sysctl = {
      "kernel.sysrq" = mkDefault 1;
      "vm.swappiness" = mkDefault 1;
    };

    nix = {
      settings = {
        auto-optimise-store = true;
      };
      gc = {
        automatic = mkDefault true;
        dates = "weekly";
        options = "--delete-older-than 30d";
      };
      extraOptions = ''
        experimental-features = nix-command flakes
      '';
    };

    system.configurationRevision = lib.mkIf (inputs.self ? rev) inputs.self.rev;

  };

}

