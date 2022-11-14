{ config, lib, pkgs, system, ... }:
with builtins; with lib; {

  options.basement.netboot = with types;
    mkOption {
      description = ''
        Configuration of a nix-basement netboot client.
      '';
      example = {
        enable = true;
        uid = "d2:ed:80:67:e1:5f";
      };
      default = { };
      type = submodule {
        options = {
          enable = mkEnableOption "Enables nix-basement netboot client configuration";
          uid = mkOption {
            description = ''
              On a UEFI/BIOS system, the MAC Address of the PXEing interface.
              On a Raspberry Pi, its Serial.

              To get a RPi's Serial run <programlisting>cat /proc/cpuinfo | grep Serial | tail -c 9</programlisting> on it.
            '';
            type = str;
            example = "d2:ed:80:67:e1:5f";
          };
          isRpi = mkOption {
            description = "is this a raspberry pi?";
            type = bool;
            default = false;
          };
          persistentStorage = mkOption {
            description = "should an rw nfs be mounted at /persistent";
            type = bool;
            default = true;
          };
        };
      };
    };
  options.basement.services.netboot-host = with types;
    mkOption {
      description = ''
        This is the server component of the nix-basement netboot system.
        </para>
        <para>
        To use it, your DHCP Server needs to have PXE configured to boot
        <itemizedlist>
          <listitem>
            <para>
              <literal>undionly</literal> for X86 BIOS systems
            </para>
          </listitem>
          <listitem>
            <para>
              <literal>snponly.efi</literal> for X86-64 UEFI systems
            </para>
          </listitem>
        </itemizedlist>
        of the tftp server running as part of this module.
        </para>
        <para>
        The following <citerefentry>
        <refentrytitle>dnsmasq</refentrytitle>
        <manvolnum>1</manvolnum>
        </citerefentry> configuration is known to work (with 192.168.3.1 as the netboot server)
        <programlisting>
        dhcp-boot=undionly,192.168.3.1
        dhcp-vendorclass=BIOS,PXEClient:Arch:00000
        dhcp-vendorclass=UEFI32,PXEClient:Arch:00006
        dhcp-vendorclass=UEFI,PXEClient:Arch:00007
        dhcp-vendorclass=UEFI64,PXEClient:Arch:00009
        dhcp-boot=net:UEFI,snponly.efi,192.168.3.1
        dhcp-boot=net:UEFI64,snponly.efi,192.168.3.1
        pxe-prompt="nix-basement netboot", 0
        pxe-service=X86PC, "biosboot", undionly,192.168.3.1
        pxe-service=X86PC, "biosboot", unionly,192.168.3.1
        pxe-service=X86-64_EFI, "uefi boot", snponly.efi,192.168.3.1
        pxe-service=X86-64_EFI, "uefi boot", snponly.efi,192.168.3.1
        pxe-service=0,"other boot",192.168.3.1
        </programlisting>
        </para>
        <para>
        The netboot server will do the following:
        <itemizedlist>
          <listitem>
            <para>
              Build the nixos configurations in into it's store
            </para>
          </listitem>
          <listitem>
            <para>
              Create a directory with all configurations and supplementary ipxe configuration
            </para>
          </listitem>
          <listitem>
            <para>
              Make this directory accessible via HTTP and TFTP (ipxe boots via HTTP)
            </para>
          </listitem>
          <listitem>
            <para>
              Make the nix store accessible via NFS
            </para>
          </listitem>
        </itemizedlist>
        </para>
        <para>
        Clients will boot via PXE, get their kernel/initramfs via HTTP (or TFTP on Raspberry Pis) and mount the NFS Store read only.
      '';
      example = {
        enable = true;
        configurations = literalExpression "[ inputs.self.nixosConfigurations.host1 ]";
      };
      default = { };
      type = submodule
        {
          options = {
            enable = mkEnableOption "Enables the nix-basement netboot server";
            nfsRanges = mkOption {
              description = "IP ranges the NFS Server should expose the nix-store on";
              default = [ "*" ];
              example = [ "192.168.3.0/24" ];
            };
            configurations = mkOption {
              description = ''
                All the nixosConfigurations that should be bootable
                all configurations have to have a <option>networking.hostName</option> and a <option>basement.netboot.uid</option>
              '';
              default = [ ];
              type = listOf raw;
            };
          };
        };

    };


  config = mkMerge [
    (
      let cfg = config.basement.netboot; in
      mkIf cfg.enable {
        boot.initrd.supportedFilesystems = [ "nfs" "nfsv4" "overlay" ];
        boot.initrd.availableKernelModules = [ "nfs" "nfsv4" "overlay" ];
        boot.initrd.network.flushBeforeStage2 = false; # otherwise nfs dosen't work
        boot.loader.grub.enable = false;
        boot.initrd.network.postCommands =
          let
            script = pkgs.writeScript "mount-dhcp" ''
              #!/bin/sh
              if [ ! -f /etc/basement-mounted ]; then
                if [ -n "''$tftp" ]; then
                  echo "TFTP=$tftp" > /etc/basement-mounted
                  mount -t nfs4 -o ro,async $tftp:/nixstore /mnt-root/nix/.ro-store
                  mount -t nfs4 -o ro $tftp:/config /mnt-root/config
                  ${optionalString cfg.persistentStorage ''
                    mount -t nfs4 -o rw,async $tftp:/storage/${config.networking.hostName} /mnt-root/persistent
                    mkdir -p /mnt-root/persistent/ssh || true
                    mkdir -p /mnt-root/etc/ssh
                    mount --bind /mnt-root/persistent/ssh /mnt-root/etc/ssh
                  ''}
               fi
              fi
            '';
          in
          ''
            echo "[nix-basement] already mounting '/' and '/nix' as fileSystems can't be generated dynamically"
            mkdir -p $targetRoot # creating /
            mount -t tmpfs -o size=2G tmpfs $targetRoot
            mkdir -m 0700 -p $targetRoot/nix/.ro-store # creating /nix
            mkdir -m 0755 -p $targetRoot/config # creating /config
            ${optionalString cfg.persistentStorage "mkdir -m 1755 -p $targetRoot/persistent"}
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
        hostNames = map (x: x.config.networking.hostName) cfg.configurations;
        uefis = filter (conf: !conf.config.basement.netboot.isRpi) nbConfigs;
        rpis = filter (conf: conf.config.basement.netboot.isRpi) nbConfigs;

        uefiConfigsArr = map (x: { "${x.config.basement.netboot.uid}" = x.config.system.build.toplevel; }) (uefis);
        uefiConfigsMap = foldr (a: b: a // b) { } uefiConfigsArr;
        uefiConfigs = toJSON uefiConfigsMap;
        rpiConfigsArr = map (x: { "${x.config.basement.netboot.uid}" = { toplevel = x.config.system.build.toplevel; fw = "${pkgs.raspberrypifw}/share/raspberrypi/boot"; }; }) (rpis);
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
            echo Remain calm while your operating system is being extracted.
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
            "bin-x86_64-efi/snponly.efi" = null;
            "bin/undionly.kpxe" = null;
          };
        };

        netbootDir =
          pkgs.runCommand "basement-netboot"
            { } ''
            mkdir $out
            ${pkgs.python3}/bin/python ${./generateIpxeConfigs.py} '${uefiConfigs}' '${ipxe}'
            ${pkgs.python3}/bin/python ${./generateRpiConfigs.py} '${rpiConfigs}'
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
        systemd.tmpfiles.rules =
          (map (y: "d /export/storage/${y} 1777 root root") hostNames) ++ [
            "d /export/config 1755 root root"
          ];
        services.nfs.server = {
          enable = true;
          exports = ''
            /export ${concatStringsSep " " (map (x: "${x}(rw,fsid=0,no_subtree_check,no_root_squash)") cfg.nfsRanges)}
            /export/config ${concatStringsSep " " (map (x: "${x}(ro,fsid=0,no_subtree_check)") cfg.nfsRanges)}
            /export/nixstore ${concatStringsSep " " (map (x: "${x}(ro,nohide,insecure,no_subtree_check)") cfg.nfsRanges)}
            ${concatStringsSep "\n" (map (y: "/export/storage/${y} ${y}(rw,nohide,insecure,no_subtree_check,no_root_squash)") hostNames)}
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
