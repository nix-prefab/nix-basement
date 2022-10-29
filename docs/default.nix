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
  moduleDocJson = import ./_support/optionsGenerator.nix { inherit pkgs lib inputs; };

  nixosModulesDoc = moduleDocJson {
    moduleRootPaths = [ ./.. ];
    title = "Nix-Basement NixOS Modules";
    baseUrl = "https://github.com/nix-basement/nix-basement/blob/main/";
    modules =
      (lib.flatten [ (map (x: ./.. + "/nixos-modules/${x}.nix") (builtins.attrNames inputs.self.nixosModules)) scrubbedPkgsModule dontCheckDefinitions ]);
  };
  darwinModulesDoc = moduleDocJson {
    moduleRootPaths = [ ./.. ];
    title = "Nix-Basement nix-darwin Modules";
    baseUrl = "https://github.com/nix-basement/nix-basement/blob/main/";
    modules =
      (lib.flatten [ (map (x: ./.. + "/darwin-modules/${x}.nix") (builtins.attrNames inputs.self.darwinModules)) scrubbedPkgsModule dontCheckDefinitions ]);
  };

  html = pkgs.runCommandNoCC "basement-docs-html" {} ''
    mkdir $out
    cp ${nixosModulesDoc.adoc} ./nixos-modules.adoc
    cp ${darwinModulesDoc.adoc} ./darwin-modules.adoc
    ls ${./.}
    cp ${./.}/*.adoc .
    ${pkgs.asciidoctor}/bin/asciidoctor -D $out *adoc
  '';
in

{
  inherit nixosModulesDoc darwinModulesDoc html;

}
