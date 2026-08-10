{ lib, ... }:
let
  inherit (lib)
    attrValues
    evalModules
    find
    getAttrFromPath
    importModule
    isAttrs
    isPath
    isString
    mapListToAttrs
    mkEnableOption
    mkIf
    nameValuePair'
    recursiveUpdate
    recursiveInsert
    removeAttrs
    removePrefix
    removeSuffix
    setAttrByPath
    setDefaultModuleLocation
    ;
in
rec {

  importModule = file:
    setDefaultModuleLocation file (import file);

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
        file: nameValuePair' (removeSuffix ".nix" (removePrefix "${modulesPath}/" file)) (importModule file)
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
    Takes a path to an option, a description for that option and a list of modules and wraps the modules, so that they may be applied by setting the newly created option to true.

    # Inputs

    `optionPath`

    : Path to the option

    `description`

    : Description for the new option

    `modules`

    : The list of modules to wrap. May be specified as either an already imported module or a path to a nix file containing a module. Specifying paths is preferred as it allows for better error messages.

    # Type

    ```
    mkEnableableModule :: [String] -> String -> [Module] -> Module
    ```
   */
  mkEnableableModule =
    optionPath: description: modules:
    { ... }: {
      imports = [(mkEnableableModule' optionPath modules)];

      options = setAttrByPath optionPath (mkEnableOption description);
    };

  /**
    Takes a path to an option and a list of modules and wrapes the modules, so that they may be applied by setting the option at the specified path to true.
    This is the same as `mkEnableableModule`, but using a preexisting option instead of creating a new one.

    # Inputs

    `optionPath`

    : Path to the option

    `modules`

    : The list of modules to wrap. May be specified as either an already imported module or a path to a nix file containing a module. Specifying paths is preferred as it allows for better error messages.

    # Type

    ```
    mkEnableableOption' :: [String] -> [Module] -> Module
    ```
  */
  mkEnableableModule' =
    optionPath: modules:
    let
      wrappedModules = map
        (module:
          let
            isFromFile = isString module || isPath module;
            moduleFn = if isFromFile
              then import module
              else module;
            wrappedModule = args@{ config, lib, pkgs, modules, modulesPath, options, utils, ...}:
              let
                evaluated = moduleFn args;
              in
              {
                options = if evaluated ? options then evaluated.options else { };
                config = if (evaluated ? config || evaluated ? options || evaluated ? imports) then evaluated.config or {} else evaluated;
              };
          in
          if isFromFile
            then setDefaultModuleLocation module wrappedModule
            else wrappedModule
        )
        modules;
    in
    mkCombinedModule wrappedModules;

}
