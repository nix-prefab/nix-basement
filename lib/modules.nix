{ lib, ... }:
let
  inherit (lib)
    attrValues
    find
    getAttrFromPath
    isAttrs
    mapListToAttrs
    mkEnableOption
    mkIf
    nameValuePair'
    recursiveUpdate
    removePrefix
    removeSuffix
    setAttrByPath
    ;
in
{

  # Find all nix files in a directory and import them.
  # Returns them as an attrset with the file names as keys
  findModules =
    modulesPath:
    if !builtins.pathExists modulesPath then
      { }
    else
      mapListToAttrs (
        file: nameValuePair' (removeSuffix ".nix" (removePrefix "${modulesPath}/" file)) (import file)
      ) (find ".nix" modulesPath);

  mkCombinedModule = modules: args: {
    imports = if isAttrs modules then attrValues modules else modules;
  };

  # Takes a path to an option, a description of a module and that module and wraps the module, so that it may be enabled by setting the newly created option to true
  mkEnableableModule =
    optionPath: description: module:
    (
      {
        config,
        lib,
        pkgs,
        modulesPath,
        ...
      }:
      let
        evaluated = module {
          inherit
            config
            lib
            pkgs
            modulesPath
            ;
        };
      in
      {
        options = recursiveUpdate (if evaluated ? options then evaluated.options else { }) (
          setAttrByPath optionPath (mkEnableOption description)
        );

        config = mkIf (getAttrFromPath optionPath config) (
          if evaluated ? config then evaluated.config else evaluated
        );
      }
    );

}
