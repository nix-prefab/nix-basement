{ lib, ... }:
with builtins; with lib; {

  findOverlays = flake: includeAll: defaultOverlay:
    let
      overlays = findOverlays' flake;
      selectedOverlays = if includeAll then (attrValues overlays) else [ ];
    in
    overlays // {
      default = final: prev:
        foldl' (flip extends) (_: prev) (selectedOverlays ++ [ defaultOverlay ]) final;
    };

  findOverlays' = inputs:
    let
      path = "${inputs.self}/overlays";
    in
    mapListToAttrs
      (file:
        nameValuePair'
          (removeSuffix ".nix" (removePrefix "${path}/" file))
          (final: prev: import file { inherit final prev lib inputs; })
      )
      (find ".nix" path);

}
