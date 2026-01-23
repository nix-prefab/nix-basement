{ lib, ... }:
with builtins;
with lib;
{
  /**
    Like nixpkgs' `nameValuePair`, but discards the string context of the name.

    # Inputs

    `name`

    : The key of the attribute

    `value`

    : The value of the attribute

    # Type

    ```
    nameValuePair' :: String -> a -> { name :: String, value :: a }
    ```
   */
  nameValuePair' =
    name: value:
    # String carries context of the derivation the file comes from.
    # It is only used as the name of an attribute here.
    # It should be safe to discard it
    nameValuePair (unsafeDiscardStringContext name) value;

  /**
    Transforms a list to an attrset with a given function

    # Inputs

    `mapper`

    : Function transforming a list element to a name-value pair

    `list`

    : List to map over

    # Type

    ```
    mapListToAttrs :: (a -> { name :: String, value :: b }) -> [a] -> AttrSet b
    ```
   */
  mapListToAttrs = mapper: list: listToAttrs (map mapper list);

  /**
    Combines a list of attrsets into a single attrset

    # Inputs

    `list`

    : List of attrsets to merge

    # Type

    ```
    recursiveUpdateList :: [AttrSet a] -> AttrSet a
    ```
   */
  recursiveUpdateList = list: foldl recursiveUpdate { } list;
}
