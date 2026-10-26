{ lib, ... }:
{
  config = {
    # Use all nixpkgs systems as a default
    systems = lib.mkDefault lib.systems.flakeExposed;
  };
}
