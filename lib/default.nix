# Entrypoint for the nix-basement library
# Returns a nixpkgs lib passed in as `super` extended with the nix-basement functions
# Returns an empty attrset if `bootstrap` is not set to prevent an infinite recursion
{ bootstrap ? false, super, ... }:
let
  overlay = (import ./base.nix { inherit super; }).loadLibOverlay ./.;
in
if bootstrap == false
then {}
else super.extend overlay
