{ lib, ... }:
with builtins; with lib; {

  findNixosModules = flake:
    if (readDir "${flake}") ? "nixos-modules" then
      findModules flake "${flake}/nixos-modules"
    else
      findModules flake "${flake}/modules";

  findDarwinModules = flake:
    findModules flake "${flake}/darwin-modules";

  findModules = flake: modulesPath:
    mapListToAttrs
      (file:
        nameValuePair'
          (removePrefix "${modulesPath}/" file)
          (import file)
      )
      (find ".nix" modulesPath);

}
