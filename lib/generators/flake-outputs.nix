{ lib, ... }:
with builtins; with lib; {

  generateFlakeOutputs =
    root:
    inputs:
    outputsFn:
    let
      # TODO Make this document-able somehow
      defaultConfig = {
        systems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
        nixpkgs = inputs.nixpkgs;
        nixpkgsConfig = { };
        checkFormatting = true;
      };

      safeInputs = inputs // { self = outputs; }; # Replace self with unprocessed outputs to avoid infinite recursion
      stories = getStories safeInputs;
      unsafeStories = getStories inputs;

      upstreamLibs = foldl recursiveUpdate config.nixpkgs.lib (map (story: story.lib) (filter (story: story ? lib) stories));
      ownLibs =
        if pathExists "${root}/lib"
        then loadLib upstreamLibs "${root}/lib"
        else { };
      mergedLibs = recursiveUpdate upstreamLibs ownLibs;

      outputs = outputsFn mergedLibs;

      config = recursiveUpdate defaultConfig (if (outputs ? basement) then outputs.basement else { });

      generatorArgs = {
        inherit config inputs outputs root stories unsafeStories;
        lib = mergedLibs;
      };
      # Run all output generators
      generatedOutputs = recursiveMerge (map (s: s.generators generatorArgs) (filter (s: s ? generators) stories));
    in
    filterAttrs
      (n: v: n != "basement") # Remove config from the output
      (
        recursiveMerge [
          generatedOutputs
          outputs
        ]
      );

  getStories =
    inputs:
    let
      storyInputs = filterAttrs (n: v: v ? story) inputs;
    in
    mapAttrsToList
      (n: v: v.story // (optionalAttrs (!v.story ? name) { name = n; }))
      storyInputs;

}
