{ lib, ... }:
let
  inherit (lib)
    mkOption
    ;
  inherit (lib.types)
    attrsOf
    anything
    functionTo
    either
    ;

  libType =
    let
      recType = either (functionTo anything) recType;
    in attrsOf recType;
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

      lib =  mkOption {
        type = libType;
        description = "A set of library functions";
        default = { };
      };
    };
  };

  # config.lib is set in the constructFlake function
}
