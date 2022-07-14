{ lib, ... }:
with builtins; with lib; {

  findNixosModules = flake:
    if pathExists "${flake}/nixos-modules" then
      findModules flake "${flake}/nixos-modules"
    else
      findModules flake "${flake}/modules";

  findDarwinModules = flake:
    findModules flake "${flake}/darwin-modules";

  findModules = flake: modulesPath:
    mapListToAttrs
      (file:
        nameValuePair'
          (
            let prefix = (removePrefix "${modulesPath}/" file); in if (hasSuffix ".nix" prefix) then (removeSuffix ".nix" prefix) else prefix
          )
          (import file)
      )
      (find ".nix" modulesPath);

}
