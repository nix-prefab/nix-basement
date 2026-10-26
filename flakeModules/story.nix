{ lib, ... }:
let
  inherit (lib)
    mkOption
    ;
  inherit (lib.types)
    nullOr
    str
    ;
in
{
  options = {
    flake.story = {
      id = mkOption {
        type = nullOr str;
        default = null;
        description = ''
          The unique identifier/name of the nix-prefab story.

          If this is set to null (the default), the story attributes are ignored.
        '';
      };
    };
  };

  config.flake.story._type = "story";
}
