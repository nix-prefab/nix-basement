{ config, lib, pkgs, ... }:

with lib;

let

  cfg = config.basement.services.gitlab-runner;

in

{
  options = {
    basement.services.gitlab-runner = {
      enable = mkEnableOption "Gitlab Runner";

      configFile = mkOption {
        default = "/Users/user/.gitlab-runner/runner.toml";
        description = ''
          Configuration file for gitlab-runner. This file is
          generated by running <command>gitlab-runner register</command>.
        '';
        type = types.path;
      };

      dataDir = mkOption {
        default = "/var/lib/gitlab-runner";
        description = ''
          The working directory for the Gitlab runner.
        '';
        type = types.str;
      };

      logFile = mkOption {
        type = types.path;
        default = "/var/log/gitlab-runner.log";
        description = ''
          The path of the log file for Gitlab runner service.
        '';
      };

    };
  };

  config = mkIf cfg.enable {

    environment.systemPackages = [ pkgs.gitlab-runner ];

    launchd.user.agents.gitlab-runner = {
      serviceConfig = {
        WorkingDirectory = cfg.dataDir;
        StandardErrorPath = cfg.logFile;
        KeepAlive = true;
        StandardOutPath = cfg.logFile;
      };
      script = ''
         ${pkgs.gitlab-runner}/bin/gitlab-runner run \
         --working-directory ${cfg.dataDir} \
        --config ${cfg.configFile}
      '';
    };

    system.activationScripts.preActivation.text = ''
      mkdir -p '${cfg.dataDir}'
      touch '${cfg.logFile}'
      chown user '${cfg.dataDir}' '${cfg.logFile}'
    '';
  };
}
