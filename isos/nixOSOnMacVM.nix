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
      users.users.root.password = "hunter2";
      security.sudo.enable = false;
      environment.defaultPackages = lib.mkForce [ ];
      nix.gc.automatic = true;
    }
    )
  ];
}).config.system.build.isoImage
