{ config, lib, getSystem, stories, ... }:
let
  inherit (lib)
    concatStringsSep
    mapAttrs
    mkOption
    mkPerSystemOption
    ;
  inherit (lib.types)
    lazyAttrsOf
    lines
    listOf
    package
    submodule
    ;
in
{
  options = {

    perSystem = mkPerSystemOption {
      _file = ./devShell.nix;

      options = {
        story = {
          shell = {
            packages = mkOption {
              type = listOf package;
              default = [ ];
              description = "A set of packages that should be available in the devShell of all stories built on top of this one";
            };
            hook = mkOption {
              type = lines;
              default = "";
              description = "Hook that should be run in the devShell of all stories built on top of this one";
            };
          };
        };

        shell = {
          packages = mkOption {
            type = listOf package;
            default = [ ];
            description = "A set of packages that should be available in the devShell";
          };
          hook = mkOption {
            type = lines;
            default = "";
            description = "A hook that should be run in the devShell";
          };
        };
      };
    };

    flake = {
      story.shell = mkOption {
        type = lazyAttrsOf (submodule {
          options = {
            packages = mkOption {
              type = listOf package;
              default = { };
              description = "See perSystem.shell.packages";
            };
            hook = mkOption {
              type = lines;
              default = "";
              description = "See perSystem.shell.hook";
            };
          };
        });
      };
      default = { };
    };

  };

  config = {
    perSystem = { system, pkgs, ... }: {
      devShells.default = pkgs.mkShell {
        buildInputs =
          (getSystem system).shell.packages
          ++
          (map
            (story: story.shell.packages)
            stories
          );

        shellHook = ''
          ${(concatStringsSep "\n" (map (story: story.shell.hook) stories))}

          ${(getSystem system).shell.hook}
        '';
      };
    };

    flake = {
      story.shell = (_: break _) (mapAttrs (system: v: {
        packages = v.story.shell.packages;
        hook = v.story.shell.hook;
      }) config.allSystems);
    };
  };
}
