{ lib, inputs, ... }:
with builtins; with lib; {

  generateNixosConfigurations = flake:
    mapAttrs
      (name: _:
        let
          metaConfig = import "${flake}/hosts/${name}" { inherit (flake) inputs lib; };
          combinedInputs = inputs // flake.inputs // { self = flake; };
          pkgs = flake.legacyPackages.${metaConfig.system};
        in
        metaConfig // (nixosSystem {
          inherit (metaConfig) system;
          specialArgs = {
            lib = flake.lib;
            system = metaConfig.system;
            inputs = combinedInputs;
          };
          modules = flatten [

            # Set the host name from the directory name
            (mkHostNameModule name)

            # Add the modules from all inputs
            (inputModules combinedInputs)

            # the system configuration
            metaConfig.modules
          ];
        })
      )
      (readDir "${flake}/hosts");

  mkHostNameModule = name:
    { config, ... }: {
      system.name = mkDefault name;
      networking.hostName = config.system.name;
    };

  inputModules = inputs':
    (filter
      (module: (typeOf module) == "lambda")
      (flatten
        (mapAttrsToList
          (name: input:
            if input ? nixosModules
            then
              (
                let
                  modules = input.nixosModules;
                in
                if (typeOf modules) == "set"
                then attrValues modules
                else modules
              )
            else
              if input ? nixosModule
              then input.nixosModule
              else [ ]
          )
          inputs'
        )
      )
    );

}
