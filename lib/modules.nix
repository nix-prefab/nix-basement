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
          (removeSuffix ".nix" (removePrefix "${modulesPath}/" file))
          (import file)
      )
      (find ".nix" modulesPath);

}
