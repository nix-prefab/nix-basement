{ lib, final, prev, ... }:
with builtins; with lib; {

  emptyScript = prev.writeShellScript "emptyScript" "";

}
