## The `generateFlakeOutputs` function
Params: Current flake root (`./.`), `inputs`, the output function
### The outout function
gets passed an argument `lib`, that contains nixpkgs.lib and additionally the library of any input stories

## A story can have the following options set:

generators: A function returning a set of attributes to automatically generate in flakes using this story
  TODO: Document how to add generators, explain all the parameters
  Note that generators that apply to the story attribute don't have an effect on the current flake

shellPackages: A function returning a list of packages that should be included in the nix-shell environment of flakes using this story

lib: A set of library functions that are added to lib for flakes using this story

nixosModules: A list of modules that should be included in all NixOS configurations (auto-generated)
darwinModules: A list of modules that should be included in all nix-darwin configurations (auto-generated)
extra{Nixos,Darwin}Modules: A list of modules that should be included as well

## A flake using nix-basement can be configured through the special `basement` flake-output:
Available options:

systems: A list of systems, that system-dependent outputs should be generated for
nixpkgs: The location of the nixpkgs that should be used
nixpkgsConfig: Extra options to pass to nixpkgs
checkFormatting: Whether or not to check formatting with `nixpkgs-fmt`

## Checks
A list of derivations that are added as a nix check. Gets passed the same things as a generator and additionally `pkgs`.


##### THINGS THAT ARE STILL MISSING #####
- overlays
- scripts (packages, apps, shell, overlay-maybe)
- packages (pakages, overlay)
- write documentation for this whole... _thing_
