attrs@{
  config,
  options,
  inputs,
  lib,
  stories,
  root,
  ...
}:
let
  inherit (lib)
    attrValues
    findModules
    getStoryDefinitions
    length
    mapAttrs
    mkCombinedOverlay
    mkEnableOption
    mkIf
    mkOption
    optional
    types
    ;

  overlay_t = (options.flake.type.getSubOptions options.flake.loc).overlays.type.nestedTypes.elemType;
in
{
  options = {
    # Get the option type from nixpkgs itself so it always stays up-to-date
    nixpkgs = {
      config = (import "${inputs.nixpkgs}/pkgs/top-level/config.nix" {
        config = null;
        lib = inputs.nixpkgs.lib;
      }).options;

      applyDefaultOverlay = mkEnableOption "Automatically apply overlays.\${system}.default when loading nixpkgs";

      overlays = mkOption {
        description = "Overlays to apply when loading nixpkgs";
        type = types.listOf overlay_t;
        default = [ ];
      };
    };

    flake = {
      story.overlay = mkOption {
        # Get the type of a single overlay from the flake-parts definition
        type = overlay_t;
      };
    };

  };

  config =
  let
    overlayModules = findModules "${root}/overlays";
    overlays' = mapAttrs (n: v: v attrs) overlayModules;
    combinedOverlay = mkCombinedOverlay (attrValues overlays');
  in
  {
    flake = {
      overlays = {
        default = mkIf (length (attrValues overlays') > 0) combinedOverlay;
      } // overlays';
    };

    perSystem =
      { system, ... }:
      {
        _module.args.pkgs = import inputs.nixpkgs {
          inherit system;
          overlays =
            config.nixpkgs.overlays
            ++ (optional config.nixpkgs.applyDefaultOverlay (f: p: (inputs.self.overlays.default or {}) f p))
            ++ (getStoryDefinitions stories [ "overlay" ])
            ;
          config = config.nixpkgs.config;
        };
      };
  };
}
