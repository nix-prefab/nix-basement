{ lib, inputs, ... }:
let
  # constructFlake gets the inputs of the calling flake passed in
  # make the inputs of nix-basement available there
  inputs' = inputs;

  inherit (builtins)
    readDir
    warn
    ;
  inherit (lib)
    attrByPath
    attrNames
    attrValues
    elem
    filter
    filterAttrs
    findModules
    foldr
    isAttrs
    loadLib
    mapListToAttrs
    mkCombinedModule
    nameValuePair
    recursiveInsert
    recursiveInsertList
    recursiveUpdateList
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
      baseLib = inputs'.nixpkgs.lib.extend (_: _: inputs'.flake-parts.lib);
      superLib = recursiveInsertList (
        [ baseLib ] ++ (getStoryDefinitions stories [ "lib" ])
      );

      # Library functions of the current story
      lib' = if (readDir root) ? lib then loadLib "${root}/lib" inputs superLib else { };

      flakeModules' = findModules "${root}/flakeModules";
      combinedModules = mkCombinedModule flakeModules';
    in
    superLib.mkFlake
      {
        inherit inputs;
        specialArgs = {
          inherit root stories inputs';
          lib = recursiveInsert superLib lib';
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
    Get all stories from the flake inputs (recursively).
    Returns an attribute set with the story IDs as the keys and the story flakes' `story` attributes as the values.

    # Inputs

    `inputs`

    : The flake inputs

    # Type

    ```
    getStories :: AttrSet Flake -> AttrSet Story
    ```
   */
  getStories =
    inputs:
    let
      otherInputs = inputs': filterAttrs (n: v: n != "self") inputs';
      storyInputs = inputs':
        attrValues (
          filterAttrs
            (n: v:
              if v ? story && v.story ? "_type" && v.story._type == "story"
                then
                  if v.story ? id
                    then true
                    else warn "Input ${n} is a story but does not have an ID, skipping" false
                else false
            )
            (otherInputs inputs')
        );
      stories = inputs':
        mapListToAttrs
          (it: nameValuePair it.story.id (it.story // { inherit (it) outPath; }))
          (storyInputs inputs');
      getStoriesRecursive = parentStories: inputs':
        let
          parentStoryIds = attrNames parentStories;
          newStories = filterAttrs
            (n: v:
              if elem n parentStoryIds
              then
                if (v.outPath == parentStories.${n}.outPath)
                  then false
                  else throw "Story ${n} is included multiple times with mismatched store paths"
              else true
            )
            (stories inputs');
        in
        foldr (v: acc: acc // (getStoriesRecursive acc (v.inputs or {}))) newStories (storyInputs inputs');
    in
    getStoriesRecursive { } inputs;

  /**
    Retrieves definitions at a given attribute path from a list of stories.

    # Inputs

    `stories`

    : List of stories

    `path`

    : Path to the attribute in each story

    # Type

    ```
    getStoryDefinitions :: AttrSet Story | [Story] -> [String] -> [?]
    ```
   */
  getStoryDefinitions =
    stories:
    path:
    filter
      (val: val != null)
      (map
        (story: attrByPath path null story)
        (if isAttrs stories
          then attrValues stories
          else stories
        )
      );
}
