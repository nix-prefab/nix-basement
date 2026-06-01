{
  description = "TODO: add description";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nmd = {
      url = "github:nix-basement/nmd";
      flake = false;
    };
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
  };

  outputs = inputs@{ self, nixpkgs, flake-utils, ... }:
    let
      lib = import ./lib { inherit inputs; };
    in
    with builtins; with lib; {
      # system independent outputs
      inherit lib;

      nixosModules = findNixosModules self;
      darwinModules = findDarwinModules self;

      overlays = findOverlays self true
        (final: prev: {
          inherit lib; # overwrite pkgs.lib with our extended lib
          agenix = inputs.agenix.packages.${prev.stdenv.hostPlatform.system}.agenix;
          base = self.packages.${prev.stdenv.hostPlatform.system}; # Add our packages to the base scope
        });

    } // (flake-utils.lib.eachDefaultSystem (system:
      let
        # import nixpkgs for the current system and set options
        pkgs = loadPkgs inputs {
          inherit system;
          allowUnfree = true;
          overlays = inputOverlays inputs;
        };
      in
      {
        # system-specific outputs
        packages = {
          decrypt = pkgs.replaceVarsWith {
            name = "decrypt";
            src = ./scripts/decrypt;
            dir = "bin";
            isExecutable = true;

            replacements = {
              inherit (pkgs) bash rage;
            };
          };
          encrypt = pkgs.replaceVarsWith {
            name = "encrypt";
            src = ./scripts/encrypt;
            dir = "bin";
            isExecutable = true;

            replacements = {
              inherit (pkgs) bash rage gnused nix;
            };
          };
          update-keys = pkgs.replaceVarsWith {
            name = "update-keys";
            src = ./scripts/update-keys;
            dir = "bin";
            isExecutable = true;

            replacements = {
              inherit (pkgs) python3 nix nixfmt;
            };
          };
        };

        apps = mapAttrs
          (name: value:
            (flake-utils.lib.mkApp {
              inherit name;
              drv = value;
            })
          )
          inputs.self.packages.${system};

        devShells.default =
          pkgs.mkShell {
            buildInputs = with pkgs;
              flatten [
                agenix
                inputs.deploy-rs.packages.${system}.deploy-rs
                nixpkgs-fmt
                rage
                (attrValues self.packages.${system})
              ];
          };

        checks = {
          nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            mkdir $out #sucess
          '';
        };

        buildJobs = generateBuildJobs self pkgs;
        docs = (import ./docs { inherit pkgs lib inputs; });

      }
    ));
}
