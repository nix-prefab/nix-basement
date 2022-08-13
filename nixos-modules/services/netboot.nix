{ config, lib, pkgs, system, ... }:
with builtins; with lib; {

  options.basement.netboot = with types; {
    enable = mkEnableOption "Enables nix-basement netboot specific settings";
    uuid = mkOption {
      description = ''uuid (or mac address) of the pxe booting interface'';
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
        boot.initrd.supportedFilesystems = [ "nfs" "nfsv4" "overlay" ];
        boot.supportedFilesystems = [ "nfs" "nfs4" ];
        boot.initrd.network.flushBeforeStage2 = false; # otherwise nfs dosen't work
        boot.initrd.postDeviceCommands = let
            script = pkgs.writeScript "mount-dhcp" ''
              #!/bin/sh
              if [ ! -f /etc/basement-mounted ]; then
                if [ -n "''$tftp" ]; then
                  touch /etc/basement-mounted
                  mount -t nfs4 -o ro $tftp:/nixstore /mnt-root/nix/.ro-store
                fi
              fi
            '';
          in
          ''
            echo "[nix-basement] already mounting '/' and '/nix' as fileSystems can't be generated dynamically"
            mkdir -p $targetRoot # creating /
            mount -t tmpfs -o size=2G tmpfs $targetRoot
            mkdir -m 0700 -p $targetRoot/nix/.ro-store # creating /nix
            for iface in $(ls /sys/class/net | grep -v ^lo$); do
              udhcpc --quit --now -i $iface -O tftp --script ${script}
            done
            echo "[nix-basement] mounted '/' and '/nix'"
          '';
        fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=2G" "remount" ]; };
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
      }
    )
    (
      let
        cfg = config.basement.services.netboot-host;


        nbConfigs = cfg.configurations;
        uefis = filter (conf: !conf.config.basement.netboot.isRpi) nbConfigs;
        rpis = filter (conf: conf.config.basement.netboot.isRpi) nbConfigs;

        uefiConfigsArr = map (x: { "${x.config.basement.netboot.uuid}" = x.config.system.build.toplevel; }) (uefis);
        uefiConfigsMap = foldr (a: b: a // b) { } uefiConfigsArr;
        uefiConfigs = toJSON uefiConfigsMap;
        rpiConfigsArr = map (x: { "${x.config.basement.netboot.uuid}" = { toplevel = x.config.system.build.toplevel; fw = "${pkgs.raspberrypifw}/share/raspberrypi/boot"; }; }) (rpis);
        rpiConfigsMap = foldr (a: b: a // b) { } rpiConfigsArr;
        rpiConfigs = toJSON rpiConfigsMap;

        ipxe = pkgs.ipxe.override {
          embedScript = pkgs.writeText "ipxe-embed.ipxe" ''
            #!ipxe
            :start
            echo
            echo Welcome to the nix-basement netboot Service
            echo
            echo Your booting will now be implemented.
            echo
            echo You'll experience a sensation of IP and then booting.
            echo Remain calm while your operating system is extracted.
            echo
            dhcp || goto dhcp_fail
            echo IP address: ''${net0/ip} ; echo Subnet mask: ''${net0/netmask}
            chain http://''${net0/next-server}/ipxe/''${net0/mac}.ipxe || chain http://''${net0/next-server}/ipxe/default.ipxe || echo Boot Failed, retry; goto retry_dhcp
            sleep 5
            goto start
            :dhcp_fail
            echo Your DHCP failed.
            echo Your state of not booting will continue.
            shell
          '';
          additionalTargets = {
            # "bin-arm64-efi/ipxe.efi" = "ipxe-aarch64.efi";
            "bin-x86_64-efi/snponly.efi" = null;
            "bin/undionly.kpxe" = null;
          };
        };

        netbootDir = pkgs.runCommand "basement-netboot" { } ''
          mkdir $out
          ${pkgs.python3}/bin/python ${./netboot/generateIpxeConfigs.py} '${uefiConfigs}' '${ipxe}'
          ${pkgs.python3}/bin/python ${./netboot/generateRpiConfigs.py} '${rpiConfigs}'
        '';


      in
      mkIf cfg.enable {
        fileSystems."/export/nixstore" = {
          device = "/nix/store";
          options = [ "bind" ];
        };
        services.atftpd = {
          enable = true;
          root = netbootDir;
        };
        services.nfs.server = {
          enable = true;
          exports = ''
            /export *(ro,fsid=0,no_subtree_check)
            /export/nixstore *(ro,nohide,insecure,no_subtree_check)
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
