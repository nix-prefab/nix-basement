{ ... }: {
  system = "x86_64-linux";
  modules = [
    ({ config, lib, pkgs, ... }: {
      boot.isContainer = true;
      system.stateVersion = "22.05";

      basement.presets.common = true;
    })
  ];
}
