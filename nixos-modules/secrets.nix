{ config, lib, pkgs, flake, ... }:
with builtins; with lib;
{
  options = with types; {
    basement.enableAgenix = mkOption {
      description = "decrypt encrypted secrets using agenix";
      type = bool;
      default = true;
    };
    secrets = mkOption {
      # type = attrsOf str;
    };
    useCommonSecrets = mkOption {
      type = bool;
      default = true;
    };
  };

  config =
    let
      sharedDir = "${flake}/secrets";
      hostDir = "${flake}/hosts/${config.system.name}/secrets";

      commonAssets = mkIf config.basement.useCommonSecrets (findAssets sharedDir);
      hostAssets = findAssets hostDir;
      allAssets = commonAssets ++ hostAssets;

      findAssets = path: if pathExists path then map (file: removePrefix "${path}/" file) (find "" path) else [ ];
      findAssetSource = name: (if elem name hostAssets then "${hostDir}" else "${sharedDir}") + "/${name}";
    in
    {
      secrets = mapListToAttrs
        (file:
          let
            file' = removeSuffix ".age" (unsafeDiscardStringContext file);
          in
          nameValuePair
            file'
            (
              if config.basement.enableAgenix && hasSuffix ".age" file
              then config.age.secrets.${file'}.path
              else findAssetSource file'
            )
        )
        allAssets;

      age = mkIf config.basement.enableAgenix {
        identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
        secrets = mapListToAttrs
          (file:
            nameValuePair'
              (removeSuffix ".age" file)
              { file = findAssetSource file; }
          )
          (
            filter
              (name: hasSuffix ".age" name)
              allAssets
          );
      };

    };
}

