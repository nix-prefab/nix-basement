{ pkgs, lib, inputs, ... }:
with lib; with builtins;
let
  # Make sure the used package is scrubbed to avoid actually
  # instantiating derivations.
  scrubbedPkgsModule = {
    imports = [{
      _module.args = {
        pkgs = lib.mkForce (nmd.scrubDerivations "pkgs" pkgs);
        pkgs_i686 = lib.mkForce { };
      };
    }];
  };

  dontCheckDefinitions = [{ _module.check = false; }];
  moduleDocJson = import ./_support/optionsGenerator.nix {inherit pkgs lib inputs;};



  nixosModulesJson = moduleDocJson
    (lib.flatten [ (map (x: ./.. + "/nixos-modules/${x}.nix") (builtins.attrNames inputs.self.nixosModules)) scrubbedPkgsModule dontCheckDefinitions ]);
  darwinModulesJson = moduleDocJson
    (lib.flatten [ (map (x: ./.. + "/darwin-modules/${x}.nix") (builtins.attrNames inputs.self.darwinModules)) scrubbedPkgsModule dontCheckDefinitions ]);
in

{
  inherit nixosModulesJson darwinModulesJson;

}
