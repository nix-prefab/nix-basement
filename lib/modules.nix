{ lib, ... }:
with builtins; with lib; {

  findNixosModules = flake:
    let
      modulesPath = "${flake}/modules";
    in
    mapListToAttrs
      (file:
        nameValuePair'
          (removePrefix "${modulesPath}/" file)
          (import file)
      )
      (find ".nix" modulesPath);

}
