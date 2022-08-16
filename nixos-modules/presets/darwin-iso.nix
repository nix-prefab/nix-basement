{ config, pkgs, lib, modulesPath, ... }:
with lib;
let
  cfg = config.basement.presets.darwinvm;
in
{
  options.basement.presets.darwinvm = mkOption {
    type = types.bool;
    default = false;
    description = "Preset for VMs booted by the linuxvm darwinModule";
  };
  config = mkIf cfg {
    services.getty.autologinUser = lib.mkForce null;
    environment.defaultPackages = lib.mkForce [ ];
    nix.gc.automatic = true;
    networking.usePredictableInterfaceNames = false;
    networking.interfaces."eth0".useDHCP = true;
    boot.loader.grub.enable = false;
    boot.initrd.availableKernelModules = [ "overlay" "virtio_net" "virtio_pci" "virtio_mmio" "virtio_blk" "virtio_scsi" "9p" "9pnet_virtio" ];
    boot.initrd.kernelModules = [ "virtio_balloon" "virtio_console" "virtio_rng" ];
    boot.initrd.supportedFilesystems = [ "squashfs" ];
    fileSystems."/" = { device = "tmpfs"; fsType = "tmpfs"; options = [ "size=2G" ]; };

    system.build.squashfsStore = pkgs.callPackage "${modulesPath}/../lib/make-squashfs.nix" {
      storeContents = [ config.system.build.toplevel ];
      comp = "zstd -Xcompression-level 6";
    };
    fileSystems."/nix/.ro-store" = {
      device = "/dev/vdb";
      fsType = "squashfs";
      neededForBoot = true;
    };
    fileSystems."/nix/.rw-store" = {
      device = "/dev/disk/by-label/nixstore";
      fsType = "ext4";
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
    fileSystems."/share" = {
      device = "hostshare";
      fsType = "9p";
      neededForBoot = false;
      options = [ "trans=virtio,version=9p2000.L" ];
    };
    boot.initrd.postDeviceCommands = ''
      if ${pkgs.parted}/bin/parted /dev/vda -- print | grep -q gpt; then
        echo "[+] Work partition already exists"
      else
        echo "[+] Work partition does not exist, creating"
        ${pkgs.parted}/bin/parted /dev/vda -- mklabel gpt
        ${pkgs.parted}/bin/parted /dev/vda -- mkpart primary 1MiB 100%
        echo "[+] Work partition created, formatting"
        ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L nixstore /dev/vda1
      fi
      ls -al /dev/disk/by-uuid /dev/disk/by-label
    '';
    system.activationScripts.copySSHHostKeys = {
      text = ''
        if [ -d "/share/ssh" ]; then
          cp -r /share/ssh/* /etc/ssh
        fi
      '';
      deps = [ "var" ];
    };
  };
}
