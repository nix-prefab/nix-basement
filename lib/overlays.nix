{ lib, ... }:
let
  inherit (lib)
    recursiveInsertList
    ;
in
{
  /**
    Takes a list of overlays and combines them into a single overlay.

    # Inputs

    `overlays`

    : List of overlays to combine

    # Type

    ```
    mkCombinedOverlay :: [Overlay] -> Overlay
    ```
   */
  mkCombinedOverlay =
    overlays: final: prev:
    recursiveInsertList (map (overlay: overlay final prev) overlays);
}
