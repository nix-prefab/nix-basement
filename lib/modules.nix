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

  /**
    Recursively find all nix files in a directory and import them.
    Returns them as an attrset with the file names as keys.

    # Inputs

    `modulesPath`

    : Path to search for nix files

    # Type

    ```
    findModules :: Path -> AttrSet ?
    ```
   */
  findModules =
    modulesPath:
    if !builtins.pathExists modulesPath then
      { }
    else
      mapListToAttrs (
        file: nameValuePair' (removeSuffix ".nix" (removePrefix "${modulesPath}/" file)) (import file)
      ) (find ".nix" modulesPath);

  /**
    Combines a list or set of modules into a single module.

    # Inputs

    `modules`

    : List or attribute set of modules

    # Type

    ```
    mkCombinedModule :: [Module] | AttrSet Module -> Module
    ```
   */
  mkCombinedModule = modules:
  { ... }: {
    imports = if isAttrs modules then attrValues modules else modules;
  };

  /**
    Takes a path to an option, a description of a module and that module and wraps the module, so that it may be enabled by setting the newly created option to true.

    # Inputs

    `optionPath`

    : Path to the option

    `description`

    : Description for the new option

    `module`

    : The module to wrap

    # Type

    ```
    mkEnableableModule :: [String] -> String -> Module -> Module
    ```
   */
  mkEnableableModule =
    optionPath: description: module:
    (
      args@{ config, ... }:
      let
        evaluated = module args;
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
