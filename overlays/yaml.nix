{ lib, final, prev, ... }:
with builtins; with lib; {

  fromYAML = input:
    let
      inFile = prev.writeText "data.yaml" input;
    in
    (fromJSON
      (readFile
        (prev.runCommand "data.json" { } ''
          ${prev.remarshal}/bin/yaml2json >"$out" <"${inFile}"
        '')
      )
    );

  toYAML = input:
    let
      inFile = prev.writeText "data.json" (toJSON input);
    in
    (readFile
      (prev.runCommand "data.yaml" { } ''
        ${prev.remarshal}/bin/json2yaml >"$out" <"${inFile}"
      '')
    );

}
