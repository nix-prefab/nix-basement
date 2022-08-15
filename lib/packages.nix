{ lib, ... }:
with builtins; with lib; {

  inputOverlays = inputs:
    map
      (input: input.overlays.default)
      (
        filter
          (input: input ? overlays && input.overlays ? default && (typeOf input.overlays.default) == "lambda")
          (attrValues inputs)
      );

  loadPkgs = inputs: config:
    import "${inputs.nixpkgs}"
      (config // {
        overlays = inputOverlays inputs;
      });

}
