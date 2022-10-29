{ lib, ... }:
with builtins; with lib; {

  findNixosModules = root:
    if pathExists "${root}/nixos-modules" then
      findModules "${root}/nixos-modules"
    else
      findModules "${root}/modules";

  findDarwinModules = root:
    findModules "${root}/darwin-modules";

  findModules = modulesPath:
    mapListToAttrs
      (file:
        nameValuePair'
          (removeSuffix ".nix" (removePrefix "${modulesPath}/" file))
          (import file)
      )
      (find ".nix" modulesPath);

  # Takes a path to an option, a description of a module and that module and wraps the module, so that it may be enabled by setting the newly created option to true
  mkEnableableModule = optionPath: description: module: (
    { config, lib, pkgs, modulesPath, ... }:
    let
      evaluated = module { inherit config lib pkgs modulesPath; };
    in
    {
      options = recursiveUpdate
        (if evaluated ? options then evaluated.options else { })
        (setAttrByPath optionPath (mkEnableOption description));

      config = mkIf (getAttrFromPath optionPath config) (if evaluated ? config then evaluated.config else evaluated);
    }
  );

}
