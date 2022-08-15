{ config, lib, pkgs, inputs, ... }:
with lib;
let
  cfg = config.basement.virtualization.linuxvm;
  isoImage = config.basement.virtualization.linuxvm.configuration.system.build.isoImage;
in
{
  options.basement.virtualization.linuxvm = mkOption {
    description = ''
      Starts a VM inside a launchctl service.
    '';
    default = { };
    type = types.submodule {
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
        type = types.uint;
        default = 6;
        description = "cores of the vm";
      };
      ram = mkOption {
        type = types.uint;
        default = 4096;
        description = "ram of the vm (in MB)";
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
  config = lib.mkIf cfg.enable {
    nix.buildMachines = [
      {
        systems = [ "aarch64-linux" ];
        supportedFeatures = [ "kvm" "big-parallel" ];
        maxJobs = 8;
        hostName = "builder";
      }
    ];
    system.activationScripts.preActivation.text = ''
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
          # hydraBuildProducts contains `file iso <absolute path to iso>`
          iso = "${isoImage}/nix-support/hydra-build-products";
        in
        ''
          echo "[-] define sshprocess function"
          export QCOWPATH="${cfg.dataDir}/nix-store.qcow2"
          echo "[-] Creating Nix Store QCOW2"
          if [[ ! -f "$QCOWPATH" ]]; then
              mkdir -p "${cfg.dataDir}"
              ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$QCOWPATH" 50G
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
            -boot d \
            -netdev user,id=mynet0,net=192.168.76.0/24,dhcpstart=192.168.76.9,${concatStringsSep "," (map (x: "hostfwd=${x}") portForwards)} \
            -device virtio-net-pci,netdev=mynet0 \
            -drive file="$(cat ${iso} | awk '{print($3)}')",media=cdrom,if=none,id=drivers \
            -device usb-storage,drive=drivers \
            -nographic -serial stdio -nodefaults \
            -drive file=${linuxpkgs.OVMF.fd}/FV/AAVMF_CODE.fd,format=raw,if=pflash,readonly=on
          echo "[-] QEMU Exited"
        '';
    };

  };
}
