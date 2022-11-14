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
    title = "NixOS Options List";
    baseUrl = "https://github.com/nix-basement/nix-basement/blob/main/";
    modules =
      (lib.flatten [ (map (x: ./.. + "/nixos-modules/${x}.nix") (builtins.attrNames inputs.self.nixosModules)) scrubbedPkgsModule dontCheckDefinitions ]);
  };
  darwinModulesDoc = moduleDocJson {
    moduleRootPaths = [ ./.. ];
    title = "nix-darwin Options List";
    baseUrl = "https://github.com/nix-basement/nix-basement/blob/main/";
    modules =
      (lib.flatten [ (map (x: ./.. + "/darwin-modules/${x}.nix") (builtins.attrNames inputs.self.darwinModules)) scrubbedPkgsModule dontCheckDefinitions ]);
  };

  fontAwesome = pkgs.fetchzip {
    url = "https://fontawesome.com/v4/assets/font-awesome-4.7.0.zip";
    sha256 = "a1z5JUXHQe4A0x+iHw5QCDZpmjZGKt2SuYW2LKowc0I=";
  };
  antoraUI = pkgs.fetchurl {
    url = "https://github.com/nix-basement/antora-ui/releases/download/0.2/ui-bundle.zip";
    sha256 = "1nk52rmcsb1yn41653lqfipy6dvi5ff55h9zpdqm1nbvnmx5pha5";
  };

  antora = (import ./_support/antora/default.nix { inherit pkgs; }).nodeDependencies;

  html = pkgs.runCommandNoCC "basement-docs-html" { } ''
    ln -s ${antora}/lib/node_modules ./node_modules
    export PATH="${antora}/bin:${pkgs.nodejs}/bin:$PATH"
    export CI=1
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
    ${pkgs.git}/bin/git config user.name "Docs Builder"
    ${pkgs.git}/bin/git config user.email "nixprefabdocs@example.org"
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
