{
  description = "TODO: add description";

  inputs = {
    nixpkgs.url = "github:thexyno/nixpkgs/iso-timeout";
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
      isos = mapAttrs (n: v: import "${self}/isos/${(last v)}" { inherit inputs; }) (zipAttrs (map (x: { "${removeSuffix ".nix" x}" = x; }) (attrNames (filterAttrs (n: v: v == "regular") (readDir "${self}/isos")))));

      darwinModules = attrValues (findDarwinModules self);

      overlays = {
        default = final: prev: {
          inherit lib; # overwrite pkgs.lib with our extended lib
          agenix = inputs.agenix.packages.${prev.system}.agenix;
          base = self.packages.${prev.system}; # Add our packages to the base scope
          deploy-rs = inputs.deploy-rs.packages.${prev.system};
        };
      };

    } // (flake-utils.lib.eachDefaultSystem (system:
      let
        # import nixpkgs for the current system and set options
        pkgs = import "${inputs.nixpkgs}" {
          inherit system;
          allowUnfree = true;
          overlays = [
            self.overlays.default
          ];
        };
      in
      {
        # system-specific outputs
        legacyPackages = pkgs; # Emit nixpkgs with our overlay

        packages = self.apps.${system};

        apps = listToAttrs
          (
            map
              (file: rec {
                name = unsafeDiscardStringContext (replaceStrings [ "/" ] [ "-" ] (removePrefix "${self}/scripts/" file)); # this is safe, actually
                value = pkgs.substituteAll {
                  inherit name;
                  src = file;
                  dir = "bin";
                  isExecutable = true;

                  # packages that are available to the scripts
                  inherit (pkgs)
                    bash
                    gnused
                    jq
                    nixFlakes
                    python3
                    rage
                    ;
                  wireguard = pkgs.wireguard-tools;
                  nixpkgs = toString inputs.nixpkgs;
                };
              })
              (find "" "${self}/scripts")

          );

        devShells.default =
          pkgs.mkShell {
            buildInputs = with pkgs; flatten [
              agenix
              deploy-rs.deploy-rs
              nixpkgs-fmt
              rage

              (attrValues self.apps.${system})
            ];
          };

        checks = {
          nixpkgs-fmt = pkgs.runCommand "check-nix-format" { } ''
            ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
            mkdir $out #sucess
          '';
        };

        buildJobs = generateBuildJobs self system;

      }
    ));
}
