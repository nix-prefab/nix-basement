{ lib, super, ... }:
let
  inherit (builtins)
    trace
    ;
  inherit (lib)
    filter
    filterAttrs
    loadLib
    mapAttrsToList
    optionalAttrs
    recursiveInsertList
    recursiveUpdate
    mkOption
    types
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
        [inputs.nixpkgs.lib] # TODO: Maybe fallback to the currently used lib if there is no nixpkgs input?
        ++
        (map (story: story.lib) (filter (story: story ? lib) stories))
      );

      # TODO: Check if the lib dir exists at all
      # Library functions of the current story
      lib' = loadLib "${root}/lib" inputs superLib;

      libOption = mkOption {
        type =
          with types;
          let
            recType = either (functionTo anything) recType;
          in attrsOf recType;
        default = { };
        description = ''
          A set of library functions
        '';
      };
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
        imports = [ module ];

         options = {
          flake = {
            story = {
              lib = libOption;
            };

            lib = libOption;
          };
        };

        config = {
          flake = {
            lib = lib';
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
