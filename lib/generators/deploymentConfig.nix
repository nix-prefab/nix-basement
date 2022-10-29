{ lib, ... }:
with builtins; with lib; {
  generateDeployConfig = inputs: {
    nodes =
      mapAttrs
        (name: metaConfig: {
          hostname = metaConfig.deployment.targetHost;
          profiles.system = {
            sshUser = metaConfig.deployment.targetUser;
            user = metaConfig.deployment.targetUser;
            path = inputs.deploy-rs.lib.${metaConfig.system}.activate.nixos metaConfig;
            fastConnection = ! metaConfig.deployment.substituteOnDestination;
          };
        })
        (
          filterAttrs
            (name: metaConfig: metaConfig ? deployment) # Are the deployment settings specified
            inputs.self.nixosConfigurations
        );
  };
}
