{ inputs, ... }:
with builtins; with inputs.nixpkgs.lib; # Use nixpkgs' lib here to prevent an infinite recursion
let
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

  lib = foldl recursiveUpdate { }
    (
      [
        { inherit find; }
        inputs.nixpkgs.lib
      ] ++ (map
        (file: import file { inherit inputs lib; })
        (filter (file: file != "${inputs.self}/lib/default.nix") (find ".nix" "${inputs.self}/lib")) # Filter out this file to prevent an infinite recursion
      )
    );
in
lib
