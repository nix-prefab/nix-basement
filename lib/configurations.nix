{ lib, ... }:
with builtins; with lib; {

  generateDarwinConfigurations = inputs:
    mapAttrs
      (name: _:
        let
          flake = inputs.self;
          metaConfig = import "${flake}/darwin-hosts/${name}" { inherit (flake) inputs lib; };
        in
        metaConfig // (inputs.darwin.lib.darwinSystem {
          inherit (metaConfig) system;
          inputs = {
            inherit inputs flake;
            pkgs = loadPkgs inputs { inherit (metaConfig) system; };
            lib = flake.lib;
            system = metaConfig.system;
          };
          modules = flatten [

            # Set the host name from the directory name
            (mkHostNameModule name)

            # Add the modules from all inputs
            (inputDarwinModules inputs)

            # the system configuration
            metaConfig.modules
          ];
        })
      )
      (readDir "${inputs.self}/darwin-hosts");

  generateNixosConfigurations = inputs:
    mapAttrs
      (name: _:
        let
          flake = inputs.self;
          metaConfig = import "${flake}/hosts/${name}" { inherit (flake) inputs lib; };
        in
        metaConfig // (nixosSystem {
          inherit (metaConfig) system;
          pkgs = loadPkgs inputs { inherit (metaConfig) system; };
          specialArgs = {
            inherit inputs flake;
            lib = flake.lib;
            system = metaConfig.system;
          };
          modules = flatten [

            # Set the host name from the directory name
            (mkHostNameModule name)

            # Add the modules from all inputs
            (inputNixOSModules inputs)

            # the system configuration
            metaConfig.modules
          ];
        })
      )
      (readDir "${inputs.self}/hosts");

  mkHostNameModuleD = name:
    { config, ... }: {
      networking.hostName = mkDefault name;
    };

  inputDarwinModules = inputs:
    (filter
      (module: (typeOf module) == "lambda")
      (flatten
        (mapAttrsToList
          (name: input:
            if input ? nixosModules
            then
              (
                let
                  modules = input.darwinModules;
                in
                if (typeOf modules) == "set"
                then attrValues modules
                else modules
              )
            else
              if input ? darwinModule
              then input.darwinModule
              else [ ]
          )
          inputs
        )
      )
    );

  inputNixOSModules = inputs:
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
