{ config, lib, pkgs, system, ... }:
with builtins; with lib; {

  options.basement.netboot = with types; {
    enable = mkEnableOption "Enables nix-basement netboot specific settings";
    uuid = mkOption {
      description = ''uuid (or mac address) of the pxe booting interface'';
      type = str;
    };
    nfsServer = mkOption {
      description = ''the IP/FQDN the NFS Server runs on'';
      type = str;
    };
    isRpi = mkOption {
      description = "is this a raspberry pi?";
      type = bool;
      default = false;
    };
  };
  options.basement.services.netboot-host = with types; {
    enable = mkEnableOption "Enables the nix-basement netboot generator";
    configurations = mkOption {
      description = ''All the nixosConfigurations that should be bootable
        all configurations have to have a `networking.hostName` and a `basement.netboot.uuid`
      '';
      type = listOf raw;
    };
  };

  config = mkMerge [
    (
      let cfg = config.basement.netboot; in mkIf cfg.enable {
        boot.initrd.availableKernelModules = [ "nfs" "nfsv4" "overlay" ];
        fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=2G" ]; };
        fileSystems."/nix/.ro-store" = {
          neededForBoot = true;
          device = "${cfg.nfsServer}:nixstore";
          fsType = "nfs4";
        };
        fileSystems."/nix/.rw-store" =
          {
            fsType = "tmpfs";
            options = [ "mode=0755" ];
            neededForBoot = true;
          };

        fileSystems."/nix/store" =
          {
            fsType = "overlay";
            device = "overlay";
            options = [
              "lowerdir=/nix/.ro-store"
              "upperdir=/nix/.rw-store/store"
              "workdir=/nix/.rw-store/work"
            ];
            depends = [
              "/nix/.ro-store"
              "/nix/.rw-store/store"
              "/nix/.rw-store/work"
            ];
          };
        boot.initrd.network.enable = true;
        networking.useDHCP = mkForce true;
        boot.supportedFilesystems = [ "nfs" "nfs4" ];
      }
    )
    (
      let
        cfg = config.basement.services.netboot-host;


        nbConfigs = cfg.configurations;
        uefis = nbConfigs;
        rpis = filter (conf: conf.config.basement.netboot.isRpi) nbConfigs;

        uefiConfigsArr = map (x: { "${x.config.basement.netboot.uuid}" = x.config.system.build.toplevel; }) (uefis);
        uefiConfigsMap = foldr (a: b: a // b) { } uefiConfigsArr;
        uefiConfigs = toJSON uefiConfigsMap;
        netbootDir = pkgs.runCommand "basement-netboot" { } ''
          ${pkgs.python3}/bin/python ${./netboot/generateSyslinuxConfigs.py} '${uefiConfigs}'
        '';


      in
      mkIf cfg.enable {
        fileSystems."/export/nixstore" = {
          device = "/nix/store";
          options = [ "bind" ];
        };
        services.atftpd = {
          enable = true;
          root = "${pkgs.ipxe.override {
            embedScript = pkgs.writeText "ipxe-embed.ipxe" ''
              #!ipxe
              :start
              echo -- Welcome to the nix-basement netboot Service --
              echo
              echo You'll first feel a little IP
              echo And then the boot will commence
              dhcp || goto dhcp_fail
              echo IP address: ''${net0/ip} ; echo Subnet mask: ''${net0/netmask}
              chain http://''${net0/next-server}/ipxe/''${net0/mac}.ipxe || chain http://''${net0/next-server}/ipxe/default.ipxe || echo Boot Failed, retry; goto retry_dhcp
              sleep 5
              goto start
              :dhcp_fail
              echo dhcp failed
              echo dropping you into a ipxe shell
              shell
            '';
            additionalTargets = {
             # "bin-arm64-efi/ipxe.efi" = "ipxe-aarch64.efi";
              "bin-x86_64-efi/snponly.efi" = null;
              "bin/undionly.kpxe" = null;
            };
          }}";
        };
        services.nfs.server = {
          enable = true;
          exports = ''
            /export 192.168.3.0/24(ro,fsid=0,no_subtree_check)
            /export/nixstore 192.168.3.0/24(ro,nohide,no_subtree_check)
          '';

        };
        services.nginx = {
          enable = true;
          virtualHosts."_".root = "${netbootDir}";
          virtualHosts."_".extraConfig = ''
            autoindex on;
          '';
        };
        networking.firewall.allowedTCPPorts = [ 80 443 67 68 69 111 2049 ];
        networking.firewall.allowedUDPPorts = [ 67 68 69 111 2049 ];
      }
    )
  ];

}
