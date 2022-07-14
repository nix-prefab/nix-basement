{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.virtualization.linuxvm;
  linuxpkgs = import inputs.nixpkgs {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };
in
{
  options.virtualization.linuxvm.enable = lib.mkEnableOption "Enables a Linux VM";
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
        launchd.user.agents.linuxvm = {
          command =
            let
              # hydraBuildProducts contains `file iso <absolute path to iso>`
              iso = builtins.elemAt (lib.splitString " " (builtins.readFile "${inputs.base.isos.nixOSOnMacVM}/nix-support/hydra-build-products")) 2;
            in
            ''
            ${pkgs.qemu}/bin/qemu-system-aarch64 \
              -accel hvf \
              -cpu host \
              -smp 6 -m 4096 \
              -M virt,highmem=off \
              -device qemu-xhci \
              -boot menu=on \
              -netdev user,id=mynet0,net=192.168.76.0/24,dhcpstart=192.168.76.9,hostfwd=tcp::5555-:22 \
              -nic user,model=virtio \
              -drive file="${iso}",media=cdrom,if=none,id=drivers \
              -device usb-storage,drive=drivers \
              -nographic -nodefaults \
              -drive file=${linuxpkgs.OVMF.fd}/FV/AAVMF_CODE.fd,format=raw,if=pflash,readonly=on &
            sleep 30
            ssh-keyscan -p 5555 localhost > /Users/user/.ssh/known_hosts
          '';
          serviceConfig.KeepAlive = true;
        };

      };
      }
