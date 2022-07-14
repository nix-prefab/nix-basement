{ config, lib, pkgs, ... }:
with builtins; with lib; {
  options.basement.services.docker = with types; {
    enable = mkEnableOption "the docker container engine";
  };

  config = mkIf config.basement.services.docker.enable {

    virtualisation = {
      oci-containers.backend = "docker";

      docker = {
        enable = true;
        liveRestore = true; # Enable restarting docker without affecting containers
        autoPrune = {
          enable = true;
          flags = [ "--all" ];
        };
      };
    };

  };
}
