{ lib, ... }:
with builtins; with lib; {
  generateSecretsNix = flake: (
    let
      keyJSON = fromJSON (readFile "${flake}/authorizedKeys.json");

      # All keys of the users listed as maintainers (can decrypt all secrets)
      maintainerKeys = flatten (
        attrValues
          (filterAttrs
            (user: key: elem user keyJSON.maintainers) # is the user a maintainer?
            keyJSON.keys
          )
      );

      # SSH host keys by hostname
      hostKeys = (
        mapAttrs
          (name: config: config.hostKey)
          (
            filterAttrs
              (name: config: config ? hostKey)
              (flake.nixosConfigurations)
          )
      );

      # All host keys as a combined list
      allHostKeys = mapAttrsToList (name: key: key) hostKeys;

      # A list of all secrets in a given directory
      findSecrets = dir:
        map
          (path: removePrefix "${flake}/" (toString path))
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
    flattenAttrs (
      flatten [
        (
          if pathExists "${flake}/secrets"
          then generateAgeConfig (allHostKeys ++ maintainerKeys) "${flake}/secrets"
          else [ ]
        )
        (mapAttrsToList
          (name: hostKey:
            if pathExists "${flake}/hosts/${name}/secrets"
            then generateAgeConfig (flatten [ hostKey maintainerKeys ]) ("${flake}/hosts/${name}/secrets")
            else [ ]
          )
          hostKeys
        )
      ]
    )
  );
}
