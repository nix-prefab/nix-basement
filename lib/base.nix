{ super, ... }:
let
  inherit (builtins)
    readDir
    ;
  inherit (super)
    attrNames
    concatStringsSep
    elemAt
    flatten
    foldl
    functionArgs
    hasSuffix
    head
    isAttrs
    isBool
    isFloat
    isFunction
    isInt
    isList
    isPath
    isString
    length
    mapAttrsToList
    recursiveUpdate
    typeOf
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
    Return a string representation of the supplied value. Unlike `builtins.toString`, this function is lazy and can also create representations of functions.

    # Inputs

    `value`

    : The value to represent as a string

    # Type

    ```
    repr :: ? -> String
    ```
   */
  repr = value:
    if isBool value then
      if value then "true" else "false"
    else if (isInt value || isFloat value) then
      toString value
    else if isString value then
      "\"${value}\""
    else if isPath value then
      "${toString value}"
    else if isList value then
      "[${concatStringsSep ", " (map repr value)}]"
    else if isAttrs value then
      if value ? "__toString" then
        value.__toString
      else if value ? "outPath" then
        "«derivation ${value.outPath}»"
      else
        "{ ${concatStringsSep " " (mapAttrsToList (n: v: "${n} = ${repr v}; ") value)}}"
    else if isFunction value then
      let
        args = functionArgs value;
      in
      if length (attrNames args) > 0 then
        "«function {${concatStringsSep ", " (mapAttrsToList (n: v: if v then n else "${n}?"))}}»"
      else
        "«function ?»"
    else
      throw "Unsupported type: ${toString (typeOf value)}";

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
            throw "Conflict at ${concatStringsSep "." here} between ${repr (head values)} and ${repr (elemAt values 1)}"
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
