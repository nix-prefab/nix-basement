{ lib, ... }:
with builtins; with lib; {
  nameValuePair' =
    name: value:
    # String carries context of the derivation the file comes from.
    # It is only used as the name of an attribute here.
    # It should be safe to discard it
    nameValuePair (unsafeDiscardStringContext name) value;

  # Maps a list to an attrset
  mapListToAttrs = mapper: list: listToAttrs (map mapper list);

  # Combines a list of attrsets into a single attrset
  flattenAttrs = list: foldl recursiveUpdate { } list;
}
