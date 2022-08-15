{ lib, ... }:
with builtins; with lib; {

  generateBuildJobs = flake: pkgs:
    let
      system = pkgs.system;
    in
    rec {
      combined = pkgs.runCommand "build-jobs-${system}" { } ''
        mkdir -p $out && cd $out

        ${concatStringsSep "\n" (
          mapAttrsToList
            (name: drv: "ln -s ${drv} ${name}")
            jobs
        )}
      '';


      jobs = flattenAttrs [

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
            (n: v: nameValuePair' "shell-${n}"
              v)
            flake.devShells.${system}
        else { })

      ];
    };

}

