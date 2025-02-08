{
  description = "Base library for nix-prefab (nix-basement)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, ... }:
  let
    bootstrapLib = import ./lib { inherit inputs; super = inputs.nixpkgs.lib; bootstrap = true; };
  in
    bootstrapLib.constructFlake { inherit inputs; root = ./.; } (
      { lib, ... }: {
        systems = [ ];

        flake = {
          story = {
            lib = self.lib;
          };
        };
      }
    );
}
