{ config, lib, pkgs, system, ... }:
with builtins; with lib; {

  options.basement.services.gitlab-runner = with types; {
    enable = mkEnableOption "GitLab runner";
    namePrefix = mkOption {
      description = "Prefix for the runner name";
      type = str;
      default = "";
    };
    concurrentJobs = mkOption {
      description = "Maximum number of jobs to run concurrently";
      type = int;
    };
    commonTags = mkOption {
      description = "Tags to add to all runners";
      type = listOf str;
    };
    commonFlags = mkOption {
      description = "Flags to add to all runners";
      type = listOf str;
      default = [ ];
    };
    configs = mkOption {
      description = "GitLab Runner regsitration configurations";
      type = attrsOf (submodule {
        options = {
          registrationConfigFile = mkOption {
            description = "GitLab Runner registration configuration file";
            type = str;
          };
          tags = mkOption {
            description = "GitLab Runner tags";
            type = listOf str;
            default = [ ];
          };
          addNixRunner = mkOption {
            description = "Add an additional runner that uses the nix daemon";
            type = bool;
            default = true;
          };
          forwardDockerSocket = mkOption {
            description = "Allow jobs to access the host's docker daemon";
            type = bool;
            default = false;
          };
          useLocalCache = mkOption {
            description = "Use a local cache for the runner (disable this if you use S3 or some other remote cache)";
            type = bool;
            default = true;
          };
        };
      });
    };
  };

  config =
    let
      cfg = config.basement.services.gitlab-runner;
    in
    mkIf cfg.enable {

      # GitLab runner uses docker
      basement.services.docker.enable = true;

      systemd.services.gitlab-runner.restartIfChanged = true;

      systemd.tmpfiles.rules = [
        "d /run/gitlab-runner 0755 root root 1d -"
      ];

      services.gitlab-runner = {
        enable = true;
        concurrent = cfg.concurrentJobs;
        services = listToAttrs
          (
            flatten (
              mapAttrsToList
                (name: values: [
                  (nameValuePair name {
                    registrationConfigFile = values.registrationConfigFile;
                    registrationFlags = [
                      "--name ${cfg.namePrefix}${config.system.name}"
                    ] ++ cfg.commonFlags;
                    tagList = [ (mkIf values.forwardDockerSocket "docker") system ] ++ values.tags ++ cfg.commonTags;
                    runUntagged = true;
                    executor = "docker";
                    dockerImage = "alpine:latest";
                    dockerPrivileged = true;
                    dockerVolumes = mkIf values.forwardDockerSocket [
                      "/var/run/docker.sock:/var/run/docker.sock"
                    ];
                    dockerDisableCache = !values.useLocalCache;
                  })
                ] ++ (if values.addNixRunner then [
                  (nameValuePair "${name}-nix" {
                    registrationConfigFile = values.registrationConfigFile;
                    registrationFlags = [
                      "--name ${cfg.namePrefix}${config.system.name}-nix"
                    ] ++ cfg.commonFlags;
                    tagList = [ "nix" ];
                    runUntagged = false;
                    executor = "docker";
                    dockerImage = "archlinux:latest";
                    dockerPrivileged = true;
                    dockerDisableCache = true; # Nix builds are cached through the nix daemon
                    preBuildScript = pkgs.writeScript "nix-setup" ''
                      mkdir -p -m 0755 /nix/var/log/nix/drvs
                      mkdir -p -m 0755 /nix/var/nix/gcroots
                      mkdir -p -m 0755 /nix/var/nix/profiles
                      mkdir -p -m 0755 /nix/var/nix/temproots
                      mkdir -p -m 0755 /nix/var/nix/userpool
                      mkdir -p -m 1777 /nix/var/nix/gcroots/per-user
                      mkdir -p -m 1777 /nix/var/nix/profiles/per-user
                      mkdir -p -m 0755 /nix/var/nix/profiles/per-user/root
                      mkdir -p -m 0700 "$HOME/.nix-defexpr"
                      . ${pkgs.nix}/etc/profile.d/nix.sh
                      ${pkgs.nix}/bin/nix-channel --add https://nixos.org/channels/nixos-unstable nixpkgs
                      ${pkgs.nix}/bin/nix-channel --update nixpkgs
                      ${pkgs.nix}/bin/nix-env -i ${concatStringsSep " " (with pkgs; [ nix cacert git openssh ])}
                      mkdir -p $HOST_EXCHANGE_DIR/$CI_JOB_ID
                    '';
                    postBuildScript = pkgs.writeScript "cleanup" ''
                      rm -rf $HOST_EXCHANGE_DIR/$CI_JOB_ID
                    '';
                    environmentVariables = {
                      ENV = "/etc/profile";
                      USER = "root";
                      NIX_REMOTE = "daemon";
                      NIX_SSL_CERT_FILE = "/nix/var/nix/profiles/default/etc/ssl/certs/ca-bundle.crt";
                      NIX_PATH = "/root/.nix-defexpr/channels";
                      PATH = "/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/bin:/sbin:/usr/bin:/usr/sbin";
                      HOST_EXCHANGE_DIR = "/run/gitlab-runner";
                    };
                    dockerVolumes = [
                      "/nix/store:/nix/store:ro"
                      "/nix/var/nix/db:/nix/var/nix/db:ro"
                      "/nix/var/nix/daemon-socket:/nix/var/nix/daemon-socket:ro"
                      "/run/gitlab-runner:/run/gitlab-runner:rw" # Add a directory for exchanging SSH keys with the nix daemon
                    ];
                  })
                ] else [ ]))
                cfg.configs
            )
          );
      };

    };

}
