{ lib, ... }:
with builtins; with lib; {

  generateDevShells = args@{ config, unsafeStories, ... }:
    mapListToAttrs
      (system:
        nameValuePair
          system
          { default = generateDevShellFor args system; }
      )
      config.systems;

  generateDevShellFor = args@{ config, unsafeStories, ... }: system:
    let
      pkgs = loadPkgs args system;
    in
    pkgs.mkShell {
      buildInputs = flatten
        (map
          (story: story.shellPackages pkgs)
          (filter (story: story ? shellPackages) unsafeStories)
        );
    };

}
