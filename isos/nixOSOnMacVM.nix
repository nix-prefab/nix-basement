{ inputs, ... }:
let
  linuxpkgs = import inputs.nixpkgs {
    system = "aarch64-linux";
    config.allowUnfree = true;
  };
in
(inputs.nixpkgs.lib.nixosSystem rec {
  system = "aarch64-linux";
  modules = [
    ({ pkgs, lib, modulesPath, ... }: {
      imports = [
        "${modulesPath}/installer/cd-dvd/installation-cd-minimal-new-kernel.nix"
      ];
      boot.loader.timeout = lib.mkForce 1; # we don't have the whole week
      users.users.root.password = "hunter2";
      services.getty.autologinUser = lib.mkForce null;
      security.sudo.enable = false;
      environment.defaultPackages = lib.mkForce [ ];
      nix.gc.automatic = true;
      lib.isoFileSystems."/nix/.rw-store" = {
        device = "/dev/disk/by-label/nixstore";
        fsType = "ext4";
        neededForBoot = true;
      };
      lib.isoFileSystems."/share" = {
        device = "hostshare";
        fsType = "9p";
        neededForBoot = false;
        options = [ "trans=virtio,version=9p2000.L" ];
      };
      boot.loader.grub.memtest86.enable = lib.mkForce false;
      boot.initrd.postDeviceCommands = ''
        if ${pkgs.parted}/bin/parted /dev/vda -- print | grep -q gpt; then
          echo "[+] meesa already have a partition"
        else
          echo "[+] meesa not have partition, so meesa parted"
          ${pkgs.parted}/bin/parted /dev/vda -- mklabel gpt
          ${pkgs.parted}/bin/parted /dev/vda -- mkpart primary 1MiB 100%
          echo "[+] meesa now have parted, so format"
          ${pkgs.e2fsprogs}/bin/mkfs.ext4 -L nixstore /dev/vda1
        fi
      '';
      system.activationScripts.copySSHHostKeys = {
        text = ''
          if [ -d "/share/ssh" ]; then
            cp -r /share/ssh/* /etc/ssh
          fi
        '';
        deps = [ "var" ];
      };

    }
    )
  ];
}).config.system.build.isoImage
