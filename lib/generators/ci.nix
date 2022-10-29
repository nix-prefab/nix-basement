{ lib, ... }:
with builtins; with lib; {

  generateBuildJobs = args@{ config, ... }:
    mapListToAttrs
      (system:
        nameValuePair
          system
          (generateBuildJobsFor args system)
      )
      config.systems;

  generateBuildJobsFor = args@{ inputs, config, ... }: system:
    let
      pkgs = loadPkgs args system;
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


      jobs = recursiveMerge [

        #nixosConfigurations
        (if inputs.self ? nixosConfigurations then
          mapAttrs'
            (name: metaConfig:
              nameValuePair'
                "nixos-system-${name}"
                metaConfig.config.system.build.toplevel
            )
            (filterAttrs
              (name: metaConfig: metaConfig.system == system)
              inputs.self.nixosConfigurations
            )
        else { })

        # packages
        (if inputs.self ? packages then
          mapAttrs'
            (n: v: nameValuePair' "pkg-${n}" v)
            inputs.self.packages.${system}
        else { })

        # devShells
        (if inputs.self ? devShells then
          mapAttrs'
            (n: v: nameValuePair' "shell-${n}"
              v)
            inputs.self.devShells.${system}
        else { })

      ];
    };

}

