args@{ super, ... }:
let
  inherit (builtins)
    readDir
    ;
  inherit (super)
    concatStringsSep
    elemAt
    flatten
    foldl
    hasSuffix
    head
    isAttrs
    length
    mapAttrsToList
    zipAttrsWith
    ;
in
rec {
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

  # Merge two attrsets recursively like `lib.recursiveUpdate`, but do not allow overwriting
  recursiveInsert =
    lhs:
    rhs:
    let recurse = attrPath:
      zipAttrsWith (n: values:
        let
          here = attrPath ++ [n];
        in
        if length values == 1
        then head values
        else
          if isAttrs (head values) && isAttrs (elemAt values 1)
          then recurse here values
          else throw "Conflict at ${concatStringsSep "." here} between ${toString (head values)} and ${toString (elemAt values 1)}"
      );
    in recurse [] [rhs lhs];

  # Recursively merge a list of attrsets, do not allow overwriting
  recursiveInsertList = list: foldl recursiveInsert { } list;

  loadLibOverlay = path: final: prev: recursiveInsertList (map (file: import file { lib = final; super = prev; }) (find ".nix" ./.));
}
