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

  fontAwesome = pkgs.fetchzip {
    url = "https://fontawesome.com/v4/assets/font-awesome-4.7.0.zip";
    sha256 = "a1z5JUXHQe4A0x+iHw5QCDZpmjZGKt2SuYW2LKowc0I=";
  };
  antoraUI =  pkgs.fetchurl {
    url = "https://gitlab.com/antora/antora-ui-default/-/jobs/artifacts/4bf07acb44a957e1830412420d3e65d25ee46f7f/raw/build/ui-bundle.zip?job=bundle-stable";
    sha256 = "17884q1wsv3wf38cwxms0j1c1v4vwl4c8arp4qcvpmf0xjw5gffc";
  };

  antora = (import ./_support/antora/default.nix { inherit pkgs; }).nodeDependencies;

  html = pkgs.runCommandNoCC "basement-docs-html" {} ''
    ln -s ${antora}/lib/node_modules ./node_modules
    export PATH="${antora}/bin:${pkgs.nodejs}/bin:$PATH"
    export docsdir=./docsrc
    #mkdir -p $out/css $out/fonts
    mkdir -p $out
    mkdir -p $docsdir/modules/ROOT/pages
    #cp -r ${fontAwesome}/css ${fontAwesome}/fonts $out/
    cp ${nixosModulesDoc.adoc} $docsdir/modules/ROOT/pages/nixos-modules.adoc
    cp ${darwinModulesDoc.adoc} $docsdir/modules/ROOT/pages/darwin-modules.adoc
    cp -r ${./.}/modules $docsdir
    cp ${antoraUI} ./uibundle.zip
    cp ${./_support}/antora-playbook.yml .
    cd $docsdir
    cp ${./.}/antora.yml .
    ${pkgs.git}/bin/git init
    ${pkgs.git}/bin/git add .
    ${pkgs.git}/bin/git commit -ma
    cd ..

    antora generate --to-dir $out antora-playbook.yml

    #cd $out
    #${pkgs.asciidoctor}/bin/asciidoctor -a webfonts! \
    #                                    -a linkcss \
    #                                    -a copycss \
    #                                    -a stylesdir=css \
    #                                    -a iconfont-remote! \
    #                                    -a toc=left \
    #                                    -a icons=font \
    #                                    -R $out -B $out -D $out $TMPDIR/*adoc
  '';
in

{
  inherit nixosModulesDoc darwinModulesDoc html;

}
