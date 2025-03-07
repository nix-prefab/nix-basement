{ lib, ... }:
let
  inherit (lib)
    mkOption
    ;
  inherit (lib.types)
    nullOr
    deferredModule
    ;
in
{
  options = {
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

  # config.flakeModules is set in the constructFlake function
}
