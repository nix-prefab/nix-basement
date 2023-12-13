{ config, lib, pkgs, ... }:
with builtins; with lib; {

  options.basement.healthchecks.providers.healthchecks-io = with types; {

    enable = mkEnableOption "healthchecks.io healthcheck provider";

    services = mkOption {
      description = "Healthchecks.io IDs or ping URLs";
      type = attrsOf str;
      default = { };
      # TODO: Example
    };

  };

  config =
    let
      cfg = config.basement.healthchecks.providers.healthchecks-io;
    in
    mkIf (config.basement.healthchecks.enable && cfg.enable) {

      basement.healthchecks.services = mkDefault (attrNames cfg.services);

      basement.healthchecks.providerFunctions =
        let
          serviceUrls = mapAttrs
            (n: v: if hasPrefix "http" v then v else "https://hc-ping.com/${v}")
            cfg.services;
        in
        [
          (service: up:
            if hasAttr service serviceUrls
            then
              pkgs.writeShellScript "healthchecks.io-${service}-${if up then "up" else "down"}" ''
                set -euxo pipefail
                ${pkgs.curl}/bin/curl -fs -m 10 --retry 5 -o /dev/null ${serviceUrls.${service}}${if !up then "/fail" else ""}
              ''
            else
              trace
                "warning: healthchecks.io is not configured for service ${service}"
                pkgs.emptyScript
          )
        ];

    };

}
