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
  options.basement.virtualization.linuxvm = {
    enable = mkEnableOption "Enables a Linux VM";
    dataDir = mkOption {
      default = "/var/lib/linuxvm";
      description = ''
        Where the linux vm's nix store resides
      '';
      type = types.str;
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
      '';
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
    environment.etc."ssh/config".text = ''
      Host builder
         HostName 127.0.0.1
         User root
         Port 5555
    '';
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
          iso = "${inputs.base.isos.nixOSOnMacVM}/nix-support/hydra-build-products";
        in
        ''
          echo "[-] define sshprocess function"
          sshprocess() {
            sleep 50
            ${pkgs.gnused}/bin/sed -i 's/.*127.0.0.1.*//;s/.*localhost.*//;/^$/d' /Users/user/.ssh/known_hosts
            ssh-keyscan -p 5555 localhost >> /Users/user/.ssh/known_hosts
            ssh-keyscan -p 5555 127.0.0.1 >> /Users/user/.ssh/known_hosts
          }
          export QCOWPATH="${cfg.dataDir}/nix-store.qcow2"
          echo "[-] Creating Nix Store QCOW2"
          if [[ ! -f "$QCOWPATH" ]]; then
              mkdir -p "${cfg.dataDir}"
              ${pkgs.qemu}/bin/qemu-img create -f qcow2 "$QCOWPATH" 50G
          fi
          echo "[-] Starting Subprocess to manage SSH Keys"
          sshprocess &
          echo "[-] Creating (maybe) host share folder"
          ${lib.optionalString (cfg.sharePath != "") "mkdir -p ${cfg.sharePath}"}
          echo "[-] Starting QEMU"
          ${pkgs.qemu}/bin/qemu-system-aarch64 \
            -accel hvf \
            -cpu host \
            -smp 6 -m 4096 \
            -M virt \
            -device qemu-xhci \
            ${lib.optionalString (cfg.sharePath != "") "-virtfs local,security_model=mapped,mount_tag=hostshare,path=${cfg.sharePath}"} \
            -hda "$QCOWPATH" \
            -boot d \
            -netdev user,id=mynet0,net=192.168.76.0/24,dhcpstart=192.168.76.9,hostfwd=tcp::5555-:22 \
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
