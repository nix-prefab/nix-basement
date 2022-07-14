{ lib, ... }:
with builtins; with lib; {

  generateBuildJobs = flake: system:
    linkFarmFromDrvs "build-jobs" (flattenAttrs [

      #nixosConfigurations
      (
        mapAttrs'
          (name: metaConfig:
            nameValuePair'
              "nixos-system-${name}"
              metaConfig.config.system.build.toplevel
          )
          (filterAttrs
            (name: metaConfig: metaConfig.system == system)
            flake.nixosConfigurations
          )
      )

      # packages
      (mapAttrs
        (n: v: nameValuePair' "pkg-${n}-${system}" v)
        flake.packages.${system}
      )

      # devShells
      (mapAttrs
        (n: v: nameValuePair' "shell-${n}-${system}" v)
        flake.devShells.${system}
      )

    ]);

}
