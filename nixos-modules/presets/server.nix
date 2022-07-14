{ config, lib, pkgs, ... }:
with builtins; with lib; {

  options.basement.presets.server = mkEnableOption "Default settings for servers";

  config = mkIf config.basement.presets.server {

    virtualisation.oci-containers.backend = "docker";
    nix.gc.automatic = mkOverride 900 true; # more than mkDefault but still less than just setting it

  };

}
