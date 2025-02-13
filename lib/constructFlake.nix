{ lib, inputs, ... }:
let
  # constructFlake gets the inputs of the calling flake passed in
  # make the inputs of nix-basement available there
  inputs' = inputs;

  inherit (builtins)
    readDir
    ;
  inherit (lib)
    filter
    filterAttrs
    findModules
    loadLib
    mapAttrsToList
    mkCombinedModule
    optionalAttrs
    recursiveInsertList
    recursiveUpdate
    ;
in
rec {
  constructFlake =
    { root
    , inputs
    , specialArgs ? { }
    }:
    module:
    let
      stories = getStories inputs;

      # Combine the base lib with all story libs
      superLib = recursiveInsertList (
        [inputs'.nixpkgs.lib]
        ++
        (map (story: story.lib) (filter (story: story ? lib) stories))
      );

      # Library functions of the current story
      lib' =
        if (readDir root) ? lib
        then
          loadLib "${root}/lib" inputs superLib
        else
          { };

      flakeModules' = findModules "${root}/flakeModules";
      combinedModules = mkCombinedModule flakeModules';
    in
    lib.mkFlake {
      inherit inputs;
      specialArgs = {
        inherit root;
        inherit stories;
        lib = recursiveUpdate superLib lib';
      } // specialArgs;
    } (
      { lib, root, inputs, ... }: {
        imports = [
          module
          combinedModules
          inputs'.flake-parts.flakeModules.flakeModules
        ]
        ++
        (map (story: story.flakeModule) (filter (story: (story.flakeModule or null) != null) stories));

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

  getStories =
    inputs:
    let
      otherInputs = filterAttrs (n: v: n != "self") inputs;
      storyInputs = filterAttrs (n: v: v ? story) otherInputs;
    in
    mapAttrsToList
      (n: v: v.story // (optionalAttrs (!v.story ? name) { name = n; }))
      storyInputs;
}
