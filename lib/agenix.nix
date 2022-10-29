{ lib, ... }:
with builtins; with lib; {
  generateSecretsNix = root: (
    let
      keyConfig = import "${root}/authorizedKeys.nix";

      # All keys of the users listed as maintainers (can decrypt all secrets)
      maintainerKeys = flatten (
        attrValues
          (filterAttrs
            (user: key: elem user keyConfig.maintainers) # is the user a maintainer?
            keyConfig.keys
          )
      );

      # SSH host keys by hostname
      hostKeys = (
        mapAttrs
          (name: config: config.hostKey)
          (
            filterAttrs
              (name: config: config ? hostKey)
              (root.nixosConfigurations)
          )
      );

      # All host keys as a combined list
      allHostKeys = mapAttrsToList (name: key: key) hostKeys;

      # A list of all secrets in a given directory
      findSecrets = dir:
        map
          (path: removePrefix "${root}/" (toString path))
          (find "" dir);

      # Generates the agenix config for all secrets in a directory, so that they are encrypted with the given keys
      generateAgeConfig = publicKeys: dir:
        mapListToAttrs
          (file:
            nameValuePair'
              (if hasSuffix ".age" file then file else "${file}.age")
              { inherit publicKeys; }
          )
          (findSecrets dir);
    in
    recursiveMerge (
      flatten [
        (
          if pathExists "${root}/secrets"
          then generateAgeConfig (allHostKeys ++ maintainerKeys) "${root}/secrets"
          else [ ]
        )
        (mapAttrsToList
          (name: hostKey:
            if pathExists "${root}/hosts/${name}/secrets"
            then generateAgeConfig (flatten [ hostKey maintainerKeys ]) ("${root}/hosts/${name}/secrets")
            else [ ]
          )
          hostKeys
        )
      ]
    )
  );
}
