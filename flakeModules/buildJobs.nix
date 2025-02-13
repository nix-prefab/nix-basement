{ config, lib, ... }:
let
  inherit (lib)
    concatStringsSep
    filterAttrs
    mapAttrs
    mapAttrsToList
    mkDefault
    mkOption
    mkPerSystemOption
    ;
  inherit (lib.types)
    attrsOf
    package
    ;
in
{
  options = {
    perSystem = mkPerSystemOption {
      _file = ./buildJobs.nix;

      options = {
        buildJobs = mkOption {
          type = attrsOf package;
          description = "A set of derivations to be built in a ci environment";
          default = { };
        };
      };
    };
  };

  config = {

    perSystem =
      {
        system,
        config,
        pkgs,
        self',
        ...
      }:
      {
        buildJobs = {
          default = mkDefault (
            pkgs.runCommand "build-jobs-${system}" { } ''
              mkdir -p $out && cd $out

              ${concatStringsSep "\n" (
                mapAttrsToList (name: drv: "ln -s ${drv} ${name}") (
                  filterAttrs (name: _: name != "default") config.buildJobs
                )
              )}
            ''
          );
        };
      };

    flake.buildJobs = mapAttrs (system: v: v.buildJobs) config.allSystems;

  };
}
