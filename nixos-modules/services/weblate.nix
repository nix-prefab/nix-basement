{ pkgs, lib, config, ... }:
with builtins; with lib;
let
  serviceName = "weblate";
in
{

  options.basement.services.weblate = with types; {
    enable = mkEnableOption "weblate web-based translation tool";
    domain = mkOption {
      type = str;
      description = "Domain under which the service will be available";
      example = "weblate.example.com";
    };
    envFile = mkOption {
      type = oneOf [ path str ];
      description = "Path to the file with weblate environment variables";
    };
    port = mkOption {
      type = int;
      description = "Port that weblate should listen on";
      default = 9592;
    };
    address = mkOption {
      type = str;
      description = "Address that weblate should listen on";
      default = "127.0.0.1";
    };
    path = mkOption {
      type = str;
      description = "Path where weblate stores its data";
      default = "/var/lib/weblate";
    };
    internalDb = mkOption {
      type = bool;
      description = "Create a postgres container for weblate";
      default = false;
    };
    backup = {
      enable = mkOption {
        type = bool;
        description = "Enable automatic backups";
        default = config.basement.services.weblate.internalDb;
      };
      target = mkOption {
        type = str;
        description = "Target directory for backups";
        default = "/var/backup";
      };
      startAt = mkOption {
        type = str;
        description = "Backup schedule in systemd format";
        default = config.services.postgresqlBackup.startAt;
        defaultText = literalExpression "config.services.postgresqlBackup.startAt";
      };
    };
  };

  config =
    let
      cfg = config.basement.services.weblate;
      backend = config.virtualisation.oci-containers.backend;
      cmd = "${config.virtualisation.${backend}.package}/bin/${backend}";
    in
    mkIf cfg.enable (mkMerge [
      {

        systemd.services."create-dockernet-${serviceName}" = {
          script = ''
            if ! ${cmd} network ls | ${pkgs.gawk}/bin/awk '{print $2;}' | grep -q ${serviceName}; then
              ${cmd} network create ${serviceName}
            fi
          '';
          wantedBy = [ "multi-user.target" ];
          after = lib.optionals (backend == "docker") [ "docker.service" "docker.socket" ];
          serviceConfig.Type = "oneshot";
        };

        virtualisation.oci-containers.containers = {

          "${serviceName}-web" = {
            image = "weblate/weblate:latest";
            extraOptions = [ "--network=${serviceName}" "--tmpfs=/app/cache" ] ++ (optional (!cfg.internalDb) "--add-host=host.docker.internal:host-gateway");
            environmentFiles = [ cfg.envFile ];
            dependsOn = [ "${serviceName}-redis" ] ++ (optional (!cfg.internalDb) "${serviceName}-db");
            environment = {
              WEBLATE_SITE_DOMAIN = cfg.domain;
              POSTGRES_HOST = mkIf cfg.internalDb "${serviceName}-db";
              REDIS_HOST = "${serviceName}-redis";
            };
            ports = [ "${cfg.address}:${toString cfg.port}:8080" ];
            volumes = [
              "${cfg.path}/data:/app/data"
            ];
          };

          "${serviceName}-redis" = {
            extraOptions = [ "--network=${serviceName}" ];
            image = "library/redis:6-alpine";
            cmd = [ "redis-server" "--appendonly" "yes" ];
            volumes = [
              "${cfg.path}/redis:/data"
            ];
          };

          "${serviceName}-db" = mkIf cfg.internalDb {
            extraOptions = [ "--network=${serviceName}" ];
            environmentFiles = [ cfg.envFile ];
            image = "library/postgres:13-alpine";
            volumes = [
              "${cfg.path}/db:/var/lib/postgresql/data"
            ];
          };

        };

        systemd.tmpfiles.rules = [
          "d ${cfg.path}/data 1700 1000 1000"
          "d ${cfg.path}/redis 1700 999 1000"
          "d ${cfg.path}/db 1700 70 70"
        ];

        services.nginx.virtualHosts."${cfg.domain}" = mkIf config.services.nginx.enable {
          forceSSL = true;
          enableACME = true;
          locations."/".proxyPass = "http://${if cfg.address != "0.0.0.0" then cfg.address else "127.0.0.1"}:${toString cfg.port}";
        };

      }
      (mkIf cfg.backup.enable {
        basement.healthchecks.services = [ "backup-${serviceName}-db" ];
        systemd.services."backup-${serviceName}-db" = {
          script = ''
            ${cmd} exec -i ${serviceName}-db /bin/bash 'PGPASSWORD=$POSTGRES_PASSWORD pg_dump -U $POSTGRES_USER $POSTGRES_DATABASE' > ${cfg.backup.target}/${serviceName}-db.sql
          '';
          after = [ "${backend}-${serviceName}-db.service" ];
          serviceConfig.Type = "oneshot";
          startAt = cfg.backup.startAt;
        };
      })
    ]);

}
