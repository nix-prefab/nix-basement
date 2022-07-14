{ lib, ... }:
with builtins; with lib; {

  findNixosModules = flake:
    if (readDir "${flake}") ? "nixos-modules" then
      findModules "${flake}/nixos-modules" flake
    else
      findModules "${flake}/modules" flake;

  findDarwinModules = flake:
    findModules "${flake}/darwin-modules" flake;


  findModules = modulesPath: flake:
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
