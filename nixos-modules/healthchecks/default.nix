{ config, lib, pkgs, ... }:
with builtins; with lib; {

  options.basement.healthchecks = with types; {

    enable = mkEnableOption "heathchecks.io monitoring";

    providerFunctions = mkOption {
      type = listOf (functionTo (functionTo package));
      default = [ ];
    };

    services = mkOption {
      type = listOf str;
      default = [ ];
      description = "Names of systemd units that should be monitored";
    };

    exclude = mkOption {
      type = listOf str;
      default = [ ];
      description = "Names of systemd units that should not be monitored (this is ownly used for the warning)";
    };

  };

  config =
    let
      cfg = config.basement.healthchecks;
    in
    mkIf cfg.enable {

      systemd.services =
        let
          generateUpdateScript = service: up: (
            concatStringsSep "\n" ([
              "set -euxo pipefail"
            ] ++ (
              map
                (provider: provider service up)
                cfg.providerFunctions
            ))
          );
        in
        (
          mapListToAttrs
            (service:
              nameValuePair
                service
                {
                  postStart = generateUpdateScript service true;
                  onFailure = [ "${service}-failure-healthcheck.service" ];
                }
            )
            cfg.services
        ) // (
          mapListToAttrs
            (service:
              nameValuePair
                "${service}-failure-healthcheck"
                {
                  enable = true;
                  script = generateUpdateScript service false;
                }
            )
            cfg.services
        );

      warnings =
        let
          unmonitored =
            filter
              (n: !elem n (cfg.services ++ cfg.exclude))
              (attrNames config.systemd.timers);
          count = length unmonitored;
        in
        optional (count > 0) "Healthcheks are enabled, but there are ${toString count} unmonitored systemd timers: ${concatStringsSep ", " unmonitored}";

    };

}
