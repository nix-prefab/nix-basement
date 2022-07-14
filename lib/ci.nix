{ lib, ... }:
with builtins; with lib; {

  generateBuildJobs = flake: targetSystems:
    linkFarmFromDrvs "build-jobs" (flattenAttrs [
      (
        mapAttrs'
          (name: metaConfig:
            nameValuePair'
              "nixos-system-${name}"
              metaConfig.config.system.build.toplevel
          )
          (filterAttrs
            (name: metaConfig: elem metaConfig.system targetSystems)
            flake.nixosConfigurations
          )
      )
      (flattenAttrs
        (map
          (system:
            (mapAttrs
              (n: v: nameValuePair' "${n}-${system}" v)
              flake.packages.${system}
            )
          )
          targetSystems
        )
      )
    ]);

}
