{
  description = "Base library for nix-prefab (nix-basement)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{ self, ... }:
    let
      bootstrapLib = import ./lib {
        inherit inputs;
        super = inputs.nixpkgs.lib;
        bootstrap = true;
      };
    in
    bootstrapLib.constructFlake
      {
        inherit inputs;
        root = ./.;
      }
      (
        { lib, getSystem, ... }:
        {
          systems = lib.systems.flakeExposed; # All nixpkgs systems

          prefab = {
            nixpkgs = {
              applyDefault = true;
              exportDefault = true;
            };
          };

          flake = {
            story = {
              id = "prefab.basement";
              flakeModule = self.flakeModules.default;
              lib = self.lib;
            };

            templates.default = {
              path = ./template;
              description = "An empty flake using nix-prefab";
            };
          };

          perSystem =
            { pkgs, system, ... }:
            {
              story = {
                shell.packages = [ ];
              };
              shell.packages = (getSystem system).story.shell.packages;

              formatter = pkgs.nixfmt-rfc-style;
            };
        }
      );
}
