{ config, lib, pkgs, flake, ... }:
with builtins; with lib;
let
  sharedDir = "${flake}/secrets";
  hostDir = "${flake}/hosts/${config.system.name}/secrets";

  commonAssets = if pathExists sharedDir then find "" "${sharedDir}" else [ ];
  hostAssets = if pathExists hostDir then find "" "${hostDir}" else [ ];
  allAssets = commonAssets ++ hostAssets;

  findAsset = name: (if elem name hostAssets then "${host}" else "${assets}") + "/${name}";
in
{
  options = with types; {
    basement.enableAgenix = mkOption {
      description = "decrypt encrypted secrets using agenix";
      type = bool;
      default = true;
    };
    secrets = mkOption {
      # type = attrsOf str;
      type = anything;
    };
  };

  config = {

    secrets = mapListToAttrs
      (file:
        nameValuePair'
          files
          (
            if config.basement.enableAgenix && hasSuffix ".age" file
            then config.age.secrets.${file}.path
            else findAsset file
          )
      )
      allAssets;

    age = mkIf config.basement.enableAgenix {
      identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
      secrets = mapListToAttrs
        (file:
          nameValuePair'
            (removeSuffix ".age" file)
            { file = findAsset file; }
        )
        (
          filter
            (name: hasSuffix ".age" name)
            allAssets
        );
    };

  };
}

