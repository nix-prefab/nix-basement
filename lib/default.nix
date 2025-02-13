# Entrypoint for the nix-basement library
# Returns the nixpkgs lib extended with the nix-basement functions
# Returns an empty attrset if `bootstrap` is not set to prevent an infinite recursion
{
  bootstrap ? false,
  inputs,
  ...
}:
let
  super = inputs.nixpkgs.lib;
in
if bootstrap == false then
  { }
else
  (import ./base.nix { inherit super; }).loadExtendedLib ./. inputs super
