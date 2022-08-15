{ config, lib, pkgs, inputs, ... }:
let
  cfg = config.basement.presets.server;
in
{
  options.basement.presets.server.enable = lib.mkEnableOption "automatic login and other settings targeted at servers";
  config = lib.mkIf cfg.enable {
    system.activationScripts.powersettings.text = ''
      sudo systemsetup -setcomputersleep Never # no sleep for u
      sudo systemsetup -setrestartpowerfailure on # start when it gets power
    '';
    nix.trustedUsers = [ "user" ];
    system.defaults = {
      loginwindow = {
        autoLoginUser = "user";
        SleepDisabled = true;
      };
    };

  };
}
