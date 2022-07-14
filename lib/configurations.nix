{ lib, ... }:
with builtins; with lib; {

  generateNixosConfigurations = inputs:
    mapAttrs
      (name: _:
        let
          flake = inputs.self;
          metaConfig = import "${flake}/hosts/${name}" { inherit (flake) inputs lib; };
        in
        metaConfig // (nixosSystem {
          inherit (metaConfig) system;
          pkgs = flake.legacyPackages.${metaConfig.system};
          specialArgs = {
            inherit inputs flake;
            lib = flake.lib;
            system = metaConfig.system;
          };
          modules = flatten [

            # Set the host name from the directory name
            (mkHostNameModule name)

            # Add the modules from all inputs
            (inputModules inputs)

            # the system configuration
            metaConfig.modules
          ];
        })
      )
      (readDir "${inputs.self}/hosts");

  mkHostNameModule = name:
    { config, ... }: {
      system.name = mkDefault name;
      networking.hostName = config.system.name;
    };

  inputModules = inputs:
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
          inputs
        )
      )
    );

}
