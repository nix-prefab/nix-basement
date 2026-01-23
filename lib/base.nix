{ super, ... }:
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
    recursiveUpdate
    zipAttrsWith
    ;
in
rec {
  /**
    Given a filename suffix and a path to a directory, recursively finds all files whose names end in that suffix.

    # Inputs

    `suffix`

    : The suffix to look for (e.g. ".nix")

    `dir`

    : The directory to search in

    # Type

    ```
    find :: String -> Path -> [Path]
    ```
   */
  find =
    suffix: dir:
    flatten (
      mapAttrsToList (
        name: type:
        if type == "directory" then
          find suffix (dir + "/${name}")
        else
          let
            fileName = dir + "/${name}";
          in
          if hasSuffix suffix fileName then fileName else [ ]
      ) (readDir dir)
    );

  /**
    Merge two attrsets recursively like `lib.recursiveUpdate`, but do not allow overwriting

    # Inputs

    `lhs`

    : First attrset

    `rhs`

    : Second attrset

    # Type

    ```
    recursiveInsert :: AttrSet ? -> AttrSet ? -> AttrSet ?
    ```
   */
  recursiveInsert =
    lhs: rhs:
    let
      recurse =
        attrPath:
        zipAttrsWith (
          n: values:
          let
            here = attrPath ++ [ n ];
          in
          if length values == 1 then
            head values
          else if isAttrs (head values) && isAttrs (elemAt values 1) then
            recurse here values
          else
            throw "Conflict at ${concatStringsSep "." here} between ${toString (head values)} and ${toString (elemAt values 1)}"
        );
    in
    recurse [ ] [ rhs lhs ];

  /**
    Recursively merge a list of attrsets, do not allow overwriting

    # Inputs

    `list`

    : List of attrsets to merge

    # Type

    ```
    recursiveInsertList :: [AttrSet a] -> AttrSet a
    ```
   */
  recursiveInsertList = list: foldl recursiveInsert { } list;

  /**
    Load a nix library from `path` and return all discovered functions as an attrset

    # Inputs

    `path`

    : The path to the library directory

    `inputs`

    : The inputs of the flake

    `super`

    : The previous library (e.g. `inputs.nixpkgs.lib`)

    # Type

    ```
    loadLib :: Path -> AttrSet Flake -> AttrSet ? -> AttrSet ?
    ```
   */
  loadLib =
    path: inputs: super:
    recursiveInsertList (
      map (
        file:
        import file {
          inherit inputs super;
          lib = loadExtendedLib path inputs super;
        }
      ) (find ".nix" path)
    );

  /**
    Like `loadLib`, but returns `super` extended with the loaded library functions

    # Inputs

    `path`

    : The path to the library directory

    `inputs`

    : The inputs of the flake

    `super`

    : The previous library (e.g. `inputs.nixpkgs.lib`)

    # Type

    ```
    loadExtendedLib :: Path -> AttrSet Flake -> AttrSet a -> AttrSet a
    ```
   */
  loadExtendedLib =
    path: inputs: super:
    recursiveUpdate super (loadLib path inputs super);
}
