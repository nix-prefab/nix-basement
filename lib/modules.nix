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
          (removePrefix "${modulesPath}/" file)
          (import file)
      )
      (find ".nix" modulesPath);

}
