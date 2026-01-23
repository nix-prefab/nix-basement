{ lib, ... }:
let
  inherit (builtins)
    readDir
    ;
  # inherit (lib)
  #   mapAttrs
  #   ;
in
with lib;
{

  # Find all top-level nix files and top-level directories containing a default.nix and import them
  # Returns them as an attribute set with the file-/directory names as the keys.
  findPackages =
    dir:
    if !builtins.pathExists dir then
      { }
    else
      mapAttrs' (
        name: type:
        let
          path = dir + "/${name}";
        in
        if type == "directory"
        then
          let
            defaultNix = path + "/default.nix";
          in
          if pathExists defaultNix then
            { inherit name; value = import defaultNix; }
          else
            null
        else
          if hasSuffix ".nix" name
          then { name = removeSuffix ".nix" name; value = import path; }
          else null
      )
      (readDir dir);
}
