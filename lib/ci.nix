{ lib, ... }:
with builtins; with lib; {

  generateBuildJobs = flake: system:
    flattenAttrs [

      #nixosConfigurations
      (if flake ? nixosConfigurations then
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
      else { })

      # packages
      (if flake ? packages then
        mapAttrs'
          (n: v: nameValuePair' "pkg-${n}" v)
          flake.packages.${system}
      else { })

      # devShells
      (if flake ? devShells then
        mapAttrs'
          (n: v: nameValuePair' "shell-${n}" v)
          flake.devShells.${system}
      else { })

    ];

}
