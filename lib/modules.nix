{ lib, ... }:
with builtins; with lib; {

  findNixosModules = flake:
    if (readDir "${flake}") ? "nixos-modules" then
      findModules "${flake}/nixos-modules"
    else
      findModules "${flake}/modules";

  findDarwinModules = flake:
    findModules "${flake}/darwin-modules";


  findModules = modulesPath: flake:
    mapListToAttrs
      (file:
        nameValuePair'
          (removePrefix "${modulesPath}/" file)
          (import file)
      )
      (find ".nix" modulesPath);

}
