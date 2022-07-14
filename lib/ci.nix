{ lib, ... }:
with builtins; with lib; {

  generateBuildJobs = flake: targetSystems:
    linkFarmFromDrvs "build-jobs" (flatten [
      (
        mapAttrsToList
          (name: metaConfig: metaConfig.config.system.build.toplevel)
          (filterAttrs
            (name: metaConfig: elem metaConfig.system targetSystems)
            flake.nixosConfigurations
          )
      )
      (flatten
        (map
          (system: (attrValues flake.packages.${system}))
          targetSystems
        )
      )
    ]);

}
