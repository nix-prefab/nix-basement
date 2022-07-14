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
      fileSystems."/nix/.rw-store" = lib.mkForce {
        device = "/dev/vda";
        fsType = "ext4";
        autoFormat = true;
        neededForBoot = true;
      };
    }
    )
  ];
}).config.system.build.isoImage
