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

  loadPkgs = { config, unsafeStories, ... }: system:
    import "${config.nixpkgs}"
      (config.nixpkgsConfig // {
        inherit system;
        # TODO: Re-Implement overlays
        # overlays = inputOverlays inputs;
      });

}
