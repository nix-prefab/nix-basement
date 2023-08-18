{ config, lib, pkgs, inputs, ... }:
with builtins; with lib; {

  options.basement.services.ssh = with types; {
    enable = mkEnableOption "OpenSSH server and key management";
    users = mkOption {
      default = { };
      type = attrsOf (submodule {
        options = {
          authorizedUsers = mkOption {
            default = [ ];
            description = "List of users in authorizedKeys.nix who should be able to log in with this account";
            type = listOf str;
          };
          authorizedKeys = mkOption {
            default = [ ];
            description = "List of additional public keys that can log in with this account";
            type = listOf str;
          };
        };
      });
    };
  };

  config =
    let
      cfg = config.basement.services.ssh;
      fileName = "${inputs.self}/authorizedKeys.nix";
      configFile =
        if pathExists fileName
        then import fileName
        else (abort "SSH key management is enabled, but no authorizedKeys.nix file was found at the flake root");
    in
    mkIf cfg.enable {

      services.openssh = {
        enable = true;
        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };
        extraConfig = ''
          AllowTcpForwarding yes
          X11Forwarding yes
          AllowAgentForwarding no
          AllowStreamLocalForwarding no
          AuthenticationMethods publickey
        '';
      };
      programs.ssh.setXAuthLocation = true;

      users.users =
        mapAttrs
          (name: value: {
            openssh.authorizedKeys.keys = (flatten (
              value.authorizedKeys
              ++
              (attrValues
                (filterAttrs
                  (name': _: elem name' value.authorizedUsers)
                  (configFile.keys)
                )
              )
            ));
          })
          (cfg.users);

    };

}
