{ pkgs, lib, inputs, ... }:
let
  nmdSrc = fetchTarball {
    url =
      "https://gitlab.com/api/v4/projects/rycee%2Fnmd/repository/archive.tar.gz?sha=91dee681dd1c478d6040a00835d73c0f4a4c5c29";
    sha256 = "07szg39wmna287hv5w9hl45wvm04zbh0k54br59nv3yzvg9ymlj4";
  };

  nmd = import nmdSrc { inherit lib pkgs; };

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

  buildModulesDocs = args:
    nmd.buildModulesDocs ({
      moduleRootPaths = [ ./.. ];
      mkModuleUrl = path:
        "https://github.com/nix-basement/nix-basement/blob/main/${path}#blob-path";
      channelName = "nix-basement";
    } // args);

  nixosModuleDocs = buildModulesDocs {
    modules = lib.flatten [ (map (x: ./.. + "/nixos-modules/${x}.nix") (builtins.attrNames inputs.self.nixosModules)) scrubbedPkgsModule dontCheckDefinitions ];
    docBook = {
      id = "nixos-options";
      optionIdPrefix = "nixos-opt";
    };
  };
  darwinModuleDocs = buildModulesDocs {
    modules = lib.flatten [ (map (x: ./.. + "/darwin-modules/${x}.nix") (builtins.attrNames inputs.self.darwinModules)) scrubbedPkgsModule dontCheckDefinitions ];
    docBook = {
      id = "nix-darwin-options";
      optionIdPrefix = "nix-darwin-opt";
    };
  };
  docs = nmd.buildDocBookDocs {
    pathName = "nix-basement";
    projectName = "Nix Basement";
    modulesDocs = [ nixosModuleDocs darwinModuleDocs ];
    documentsDirectory = ./.;
    documentType = "book";
    chunkToc = ''
      <toc>
        <d:tocentry xmlns:d="http://docbook.org/ns/docbook" linkend="book-nix-basement-manual"><?dbhtml filename="index.html"?>
          <d:tocentry linkend="ch-nixos-options"><?dbhtml filename="nixos-options.html"?></d:tocentry>
          <d:tocentry linkend="ch-nix-darwin-options"><?dbhtml filename="nix-darwin-options.html"?></d:tocentry>
        </d:tocentry>
      </toc>
    '';
  };
in

{
  inherit nmdSrc;

  options = {
    nixos-json = nixosModuleDocs.json.override {
      path = "share/doc/nix-basement/nixos-modules.json";
    };
    darwin-json = darwinModuleDocs.json.override {
      path = "share/doc/nix-basement/darwin-modules.json";
    };
  };

  manPages = docs.manPages;

  manual = { inherit (docs) html htmlOpenTool; };


}
