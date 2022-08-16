{ config, lib, pkgs, inputs, ... }:
with lib;
let
  cfg = config.basement.virtualization.linuxvm;
  linuxpkgs = import inputs.nixpkgs {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };
in
{
  options.basement.virtualization.linuxvm = mkOption {
    description = ''
      Starts a VM inside a launchctl service.
    '';
    default = { };
    type = types.submodule {
      options = {
        enable = mkEnableOption "Enables a Linux VM";
        configuration = mkOption {
          type = types.raw;
          description = ''nixosConfiguration (of system aarch64) that has <literal>nix-basement.presets.darwin-iso.enable = true</literal>'';
        };
        dataDir = mkOption {
          default = "/var/lib/linuxvm";
          description = ''
            Where the linux vm's nix store resides
          '';
          type = types.str;
        };
        cores = mkOption {
          type = types.int;
          default = 6;
          description = "cores of the vm";
        };
        ram = mkOption {
          type = types.int;
          default = 4096;
          description = "ram of the vm (in MB)";
        };
        rwStoreSize = mkOption {
          type = types.str;
          default = "50G";
          description = "Size of the vm's nix store";
        };
        portForwards = mkOption {
          description = "syntax: <literal>tcp/udp:hostip:hostport-guestip:guestport</literal> hostip/guestip can be omitted.";
          type = types.listOf types.str;
          default = [ "tcp::5555-:22" ];
        };
        logFile = mkOption {
          type = types.path;
          default = "/var/log/linuxvm.log";
          description = ''
            The path of the log file for the linuxvm service.
          '';
        };
        sharePath = mkOption {
          type = types.path;
          default = "/Users/user/vmshare";
          description = ''
            Path to share to the VM

            if the path contains a folder named <literal>ssh</literal>, contents are copied to /etc/ssh on the VM
          '';
        };
      };

    };
  };
  config = lib.mkIf cfg.enable {
    nix.buildMachines = [
      {
        systems = [ "aarch64-linux" ];
        supportedFeatures = [ "kvm" "big-parallel" ];
        maxJobs = 8;
        hostName = "builder";
      }
    ];
    system.activationScripts.nix-basement-linuxvm.text = ''
      mkdir -p '${cfg.dataDir}'
      touch '${cfg.logFile}'
    '';
    launchd.daemons.linuxvm = {
      serviceConfig = {
        KeepAlive = true;
        WorkingDirectory = cfg.dataDir;
        StandardErrorPath = cfg.logFile;
        StandardOutPath = cfg.logFile;
      };
      script =
        let
          tl = cfg.configuration.config.system.build.toplevel;
          store = cfg.configuration.config.system.build.squashfsStore;
        in
        ''
          echo "[-] define sshprocess function"
          export QCOWPATH="${cfg.dataDir}/nix-store.qcow2"
          echo "[-] Creating Nix Store QCOW2"
          if [[ ! -f "$QCOWPATH" ]]; then
              mkdir -p "${cfg.dataDir}"
              ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$QCOWPATH" ${cfg.rwStoreSize}
          fi
          echo "[-] Creating (maybe) host share folder"
          ${lib.optionalString (cfg.sharePath != "") "mkdir -p ${cfg.sharePath}"}
          echo "[-] Starting QEMU"
          ${pkgs.qemu}/bin/qemu-system-aarch64 \
            -accel hvf \
            -cpu host \
            -smp ${toString cfg.cores} -m ${toString cfg.ram} \
            -M virt \
            -device qemu-xhci \
            ${lib.optionalString (cfg.sharePath != "") "-virtfs local,security_model=mapped,mount_tag=hostshare,path=${cfg.sharePath}"} \
            -hda "$QCOWPATH" \
            -drive index=1,file="${store}",format=raw,media=disk \
            -netdev user,id=mynet0,net=192.168.76.0/24,dhcpstart=192.168.76.9,${concatStringsSep "," (map (x: "hostfwd=${x}") cfg.portForwards)} \
            -device virtio-net-pci,netdev=mynet0 \
            -kernel "${tl}/kernel" \
            -initrd "${tl}/initrd" \
            -append "initrd=initrd init=${tl}/init console=ttyAMA0 $(cat ${tl}/kernel-params)" \
            -nographic -serial stdio -nodefaults \
            -drive file=${linuxpkgs.OVMF.fd}/FV/AAVMF_CODE.fd,format=raw,if=pflash,readonly=on
          echo "[-] QEMU Exited"
        '';
    };

  };
}
