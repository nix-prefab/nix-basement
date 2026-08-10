{ lib, ... }:
let
  inherit (lib)
    mkOption
    ;
  inherit (lib.types)
    attrsOf
    raw
    ;

  libType = attrsOf raw;
in
{
  options = {
    flake = {
      story = {
        lib = mkOption {
          type = libType;
          description = "A set of library functions that should be available built in stories built on top of this one";
          default = { };
        };
      };

      lib = mkOption {
        type = libType;
        description = "A set of library functions";
        default = { };
      };
    };
  };

  # config.lib is set in the constructFlake function
}
