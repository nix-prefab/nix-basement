{ config, lib, ... }:
let
  inherit (lib)
    mkIf
    mkOption
    ;

  inherit (lib.types)
    bool
    deferredModule
    nullOr
    ;
in
{
  options = {
    prefab.flakeModules = {
      exportDefault = mkOption {
        type = bool;
        description = "Export the default flake module as a story output";
        default = true;
      };
    };

    flake = {
      story = {
        flakeModule = mkOption {
          type = nullOr deferredModule;
          description = "A flake parts flakeModule that should be loaded in all stories built on top of this one";
          default = null;
        };
      };
    };
  };

  config = {
    flake.story.flakeModule = mkIf config.prefab.flakeModules.exportDefault config.flake.flakeModules.default;
    # config.flakeModules is set in the constructFlake function
  };

}
