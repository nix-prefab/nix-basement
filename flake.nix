{
  description = "Base library for nix-prefab (nix-basement)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    nmd = {
      url = "github:nix-basement/nmd";
      flake = false;
    };
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
  let
    bootstrapLib = import ./lib { bootstrap = true; super = inputs.nixpkgs.lib; };
  in
    bootstrapLib.constructFlake ./. inputs (lib: with builtins; with lib; {

        generators = args@{ config, inputs, outputs, root, stories, unsafeStories, ... }:
          (recursiveMerge [
            {

              devShells = generateDevShells args;

              buildJobs = generateBuildJobs args;

              checks = generateChecks args;

            }

            (optionalAttrs (pathExists "${root}/lib") {
              story.lib = inputs.self.lib;
              lib = baseLib.loadLib lib "${root}/lib";
            })

            (optionalAttrs (pathExists "${root}/nixos-modules" || pathExists "${root}/modules") {
              story.nixosModules = (attrValues inputs.self.nixosModules) ++ inputs.self.story.extraNixosModules;
              story.extraNixosModules = [ ];
              nixosModules = findNixosModules root;
            })

            (optionalAttrs (pathExists "${root}/darwin-modules") {
              story.darwinModules = (attrValues inputs.self.darwinModules) ++ inputs.self.story.extraDarwinModules;
              story.extraDarwinModules = [ ];
              darwinModules = findDarwinModules root;
            })

            (optionalAttrs (pathExists "${root}/hosts") {
              nixosConfigurations = generateNixosConfigurations args;
              darwinConfigurations = generateDarwinConfigurations args;
            })

            (optionalAttrs (pathExists "${root}/scripts") (
              let
                a = b;
              in
              { }
            ))

            (optionalAttrs (pathExists "${root}/docs") {
              docs = mapListToAttrs
                (system:
                  nameValuePair
                    system
                    (import ./docs { inherit lib inputs; pkgs = loadPkgs args system; })
                )
                config.systems;
            })

          ]);

        extraNixosModules = [
          inputs.agenix.nixosModules.age
        ];

        shellPackages = pkgs: with pkgs; [
          nixpkgs-fmt
        ];

        checks = { pkgs, root, config, ... }: flatten [
          (optional config.checkFormatting (pkgs.runCommand "nixpkgs-fmt-check" { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${root} && mkdir $out
          ''))
        ];

      };

    });
}
