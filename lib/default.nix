{ lib, ... }:
with builtins; with lib; rec {

  # This file is called with nixpkgs.lib to import the rest of the library
  # and may therefore only use functions that are avaliable in nixpkgs

  # Given a filename suffix and a path to a directory,
  # recursively finds all files whose names end in that suffix.
  # Returns the filenames as a list
  find =
    suffix: dir:
    flatten (
      mapAttrsToList
        (
          name: type:
          if type == "directory" then
            find suffix (dir + "/${name}")
          else
            let
              fileName = dir + "/${name}";
            in
            if hasSuffix suffix fileName
            then fileName
            else [ ]
        )
        (readDir dir)
    );

  # Extends the nixpkgs library that is passed into here with the one in the given directory
  loadLib =
    base:
    path:
    let

      # Only the custom library functions
      standalone = foldl recursiveUpdate { }
        (map
          (file: import file { lib = extended; })
          (find ".nix" path)
        );

      # The base library extended with the custom functions
      extended = recursiveUpdate base standalone;

    in
    standalone;

}
