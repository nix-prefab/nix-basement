attrs@{
  config,
  options,
  inputs,
  inputs',
  lib,
  stories,
  root,
  ...
}:
let
  inherit (lib)
    attrValues
    findPackages
    getStoryDefinitions
    length
    mapAttrs
    mkCombinedOverlay
    mkEnableOption
    mkOption
    optional
    types
    ;

  nixpkgs = inputs.nixpkgs or inputs'.nixpkgs;

  # Get the option type from nixpkgs itself so it always stays up-to-date
  overlay_t = (options.flake.type.getSubOptions options.flake.loc).overlays.type.nestedTypes.elemType;
in
{
  options = {
    prefab.nixpkgs = {
      config = (import "${nixpkgs}/pkgs/top-level/config.nix" {
        config = null;
        lib = nixpkgs.lib;
      }).options;

      applyDefaultOverlay = mkEnableOption "Automatically apply overlays.\${system}.default when loading nixpkgs";

      overlays = mkOption {
        description = "Additional overlays to apply when loading nixpkgs";
        type = types.listOf overlay_t;
        default = [ ];
      };

      appliedOverlays = mkOption {
        description = "Overlays that are applied when loading nixpkgs";
        type = types.listOf overlay_t;
        default = [ ];
        readOnly = true;
      };
    };

    flake = {
      story.overlay = mkOption {
        # Get the type of a single overlay from the flake-parts definition
        type = types.nullOr overlay_t;
        default = null;
      };
    };

  };

  config =
  let
    overlayFiles = findPackages "${root}/overlays";
    overlays = mapAttrs (n: v: v attrs) overlayFiles;
    combinedOverlay = mkCombinedOverlay (attrValues overlays);
  in
  {
    flake = {
      prefab.nixpkgs.appliedOverlays = config.prefab.nixpkgs.overlays
        ++ (optional config.prefab.nixpkgs.applyDefaultOverlay (f: p: (inputs.self.overlays.default or {}) f p))
        ++ (getStoryDefinitions stories [ "overlay" ]);

      overlays =
        let
          defaultAttr = if (length (attrValues overlays) > 0)
            then { default = combinedOverlay; }
            else {};
        in
        defaultAttr // overlays;
    };

    perSystem =
      { system, ... }:
      {
        _module.args.pkgs = import nixpkgs {
          inherit system;
          overlays = config.prefab.nixpkgs.overlays;
          config = config.prefab.nixpkgs.config;
        };
      };
  };
}
