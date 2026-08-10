{

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    basement = {
      url = "github:nix-prefab/nix-basement#flake-part-stories";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: inputs.basement.lib.constructFlake
    { inherit inputs; root = ./.; }
    ({ lib, ... }: {

      systems = [ ]; # Add your supported systems here

    });

}
