{ lib, inputs, ... }:
let
  # constructFlake gets the inputs of the calling flake passed in
  # make the inputs of nix-basement available there
  inputs' = inputs;

  inherit (builtins)
    readDir
    ;
  inherit (lib)
    attrByPath
    filter
    filterAttrs
    findModules
    loadLib
    mapAttrsToList
    mkCombinedModule
    optionalAttrs
    recursiveInsertList
    recursiveUpdate
    setDefaultModuleLocation
    ;
in
rec {
  /**
    Constructs a flake from a root directory and inputs.

    # Inputs

    `args`

    : Set containing `root`, `inputs`, and optionally `specialArgs`

    `args.root`

    : A path value pointing to the root directory of the flake

    `args.inputs`

    : The inputs of the flake

    `args.specialArgs`

    : Optional special arguments to pass to all flake modules

    `module`

    : The root flake module to evaluate

    # Type

    ```
    constructFlake :: { root :: Path, inputs :: AttrSet Flake, specialArgs :: AttrSet ? } -> Module -> Flake
    ```
   */
  constructFlake =
    {
      root,
      inputs,
      specialArgs ? { },
    }:
    module:
    let
      stories = getStories inputs;

      # Combine the base lib with all story libs
      superLib = recursiveInsertList (
        [ inputs'.nixpkgs.lib ] ++ (map (story: story.lib) (filter (story: story ? lib) stories))
      );

      # Library functions of the current story
      lib' = if (readDir root) ? lib then loadLib "${root}/lib" inputs superLib else { };

      flakeModules' = findModules "${root}/flakeModules";
      combinedModules = mkCombinedModule flakeModules';
    in
    lib.mkFlake
      {
        inherit inputs;
        specialArgs = {
          inherit root stories inputs';
          lib = recursiveUpdate superLib lib';
        } // specialArgs;
      }
      (
        {
          lib,
          root,
          inputs,
          ...
        }:
        {
          imports = [
            (setDefaultModuleLocation (toString root + "/flake.nix") module)
            combinedModules
            inputs'.flake-parts.flakeModules.flakeModules
          ] ++ (getStoryDefinitions stories [ "flakeModule" ]);

          config = {
            flake = {
              lib = lib';
              flakeModules = {
                default = combinedModules;
              } // flakeModules';
            };
          };
        }
      );

  /**
    Get all stories from the flake inputs.

    # Inputs

    `inputs`

    : The flake inputs

    # Type

    ```
    getStories :: AttrSet Flake -> [Story]
    ```
   */
  getStories =
    inputs:
    let
      otherInputs = filterAttrs (n: v: n != "self") inputs;
      storyInputs = filterAttrs (n: v: v ? story) otherInputs;
    in
    mapAttrsToList (n: v: v.story // (optionalAttrs (!v.story ? name) { name = n; })) storyInputs;

  /**
    Retrieves definitions at a given attribute path from a list of stories.

    # Inputs

    `stories`

    : List of stories

    `path`

    : Path to the attribute in each story

    # Type

    ```
    getStoryDefinitions :: [AttrSet Story] -> [String] -> [?]
    ```
   */
  getStoryDefinitions =
    stories:
    path:
    filter (val: val != null) (map (story: attrByPath path null story) stories);
}
