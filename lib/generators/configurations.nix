{ lib, ... }:
with builtins; with lib;
let
  allHostConfigs = args@{ root, lib, ... }:
    mapAttrs
      (name: _:
        import "${root}/hosts/${name}" args
      )
      (readDir "${root}/hosts");

  hostsByOs = os: args:
    filterAttrs
      (_: metaConfig: metaConfig ? system && (hasSuffix "-${os}" metaConfig.system))
      (allHostConfigs args);

  generateConfigurations = os: args@{ lib, inputs, config, unsafeStories, ... }:
    let
      mkSystem =
        if os == "linux"
        then (args.lib.nixosSystem)
        else (args.lib.darwinSystem);
      osModules =
        if os == "linux"
        then "nixosModules"
        else "darwinModules";
      storyModules = flatten (map (story: story.${osModules}) (filter (hasAttr osModules) unsafeStories));
    in
    mapAttrs
      (name: metaConfig:
        metaConfig // (mkSystem {
          inherit (metaConfig) system;
          specialArgs = {
            inherit metaConfig;
            inherit (args) inputs lib;
            pkgs = loadPkgs args metaConfig.system;
          };
          modules = flatten [
            storyModules
            (mkHostNameModule name)
            metaConfig.modules
          ];
        })
      )
      (hostsByOs os args);
in
{

  generateNixosConfigurations = generateConfigurations "linux";
  generateDarwinConfigurations = generateConfigurations "darwin";

  mkHostNameModule = name:
    { config, ... }: {
      networking.hostName = mkDefault name;
    };

}
