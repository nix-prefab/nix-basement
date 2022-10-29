{ lib, ... }:
with builtins; with lib; {

  generateChecks = args@{ config, stories, ... }:
    mapListToAttrs
      (system:
        let
          pkgs = loadPkgs args system;
        in
        nameValuePair
          system
          (mapListToAttrs
            (story:
              nameValuePair
                story.name
                (pkgs.linkFarmFromDrvs story.name
                  (story.checks (args // { inherit pkgs; }))
                )
            )
            (filter (hasAttr "checks") stories)
          )
      )
      config.systems;

}
