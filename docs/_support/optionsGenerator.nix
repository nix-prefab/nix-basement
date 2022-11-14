{ pkgs, lib, inputs, ... }:
{ moduleRootPaths, modules, baseUrl, title }:
with lib; with builtins;
let

  moduleDocJson = modules: (jsonFile (jsonData (moduleDoc modules)));

  moduleDoc = modules: (map cleanUpOption (
    (sort moduleDocCompare
      (filter (opt: opt.visible && !opt.internal)
        (optionAttrSetToDocList (evalModules { inherit modules; }).options)))
  ));
  jsonData = optionsDocs:
    let
      trimAttrs = flip removeAttrs [ "name" "visible" "internal" ];
      attributify = opt: {
        inherit (opt) name;
        value = trimAttrs opt;
      };
    in
    listToAttrs (map attributify optionsDocs);

  jsonFile = jD:
    pkgs.writeTextFile {
      name = builtins.baseNameOf "options";
      destination = "/options.json";
      text = builtins.unsafeDiscardStringContext (builtins.toJSON jD);
    };
  # Generate some meta data for a list of packages. This is what
  # `relatedPackages` option of `mkOption` lib/options.nix influences.
  #
  # Each element of `relatedPackages` can be either
  # - a string:   that will be interpreted as an attribute name from `pkgs`,
  # - a list:     that will be interpreted as an attribute path from `pkgs`,
  # - an attrset: that can specify `name`, `path`, `package`, `comment`
  #   (either of `name`, `path` is required, the rest are optional).
  mkRelatedPackages =
    let
      unpack = p:
        if isString p then {
          name = p;
        } else if isList p then {
          path = p;
        } else
          p;

      repack = args:
        let
          name = args.name or (concatStringsSep "." args.path);
          path = args.path or [ args.name ];
          pkg = args.package or (
            let
              bail = throw "Invalid package attribute path '${toString path}'";
            in
            attrByPath path bail pkgs
          );
        in
        {
          attrName = name;
          packageName = pkg.meta.name;
          available = pkg.meta.available;
        } // optionalAttrs (pkg.meta ? description) {
          inherit (pkg.meta) description;
        } // optionalAttrs (pkg.meta ? longDescription) {
          inherit (pkg.meta) longDescription;
        } // optionalAttrs (args ? comment) { inherit (args) comment; };
    in
    map (p: repack (unpack p));

  moduleDocCompare = a: b:
    let
      isEnable = lib.hasPrefix "enable";
      isPackage = lib.hasPrefix "package";
      compareWithPrio = pred: cmp: splitByAndCompare pred compare cmp;
      moduleCmp = compareWithPrio isEnable (compareWithPrio isPackage compare);
    in
    compareLists moduleCmp a.loc b.loc < 0;

  cleanUpOption = opt:
    let
      applyOnAttr = n: f: optionalAttrs (hasAttr n opt) { ${n} = f opt.${n}; };
    in
    opt // applyOnAttr "declarations" (map mkDeclaration)
    // applyOnAttr "example" substFunction
    // applyOnAttr "default" substFunction // applyOnAttr "type" substFunction
    // applyOnAttr "relatedPackages" mkRelatedPackages;

  mkDeclaration = decl: rec {
    path = stripModulePathPrefixes decl;
    url = baseUrl + path;
  };

  # We need to strip references to /nix/store/* from the options or
  # else the build will fail.
  stripModulePathPrefixes =
    let prefixes = map (p: "${toString p}/") moduleRootPaths;
    in modulePath: fold removePrefix modulePath prefixes;

  # Replace functions by the string <function>
  substFunction = x:
    if builtins.isAttrs x then
      mapAttrs (name: substFunction) x
    else if builtins.isList x then
      map substFunction x
    else if isFunction x then
      "<function>"
    else
      x;

  j2a = pkgs.substituteAll { src = ./optionsJsonToAdoc.py; pandoc = pkgs.pandoc; python = pkgs.python3; };
  jsonToAdoc = jsonFile: pkgs.runCommandNoCC "jsonToAdoc" { } ''
    ${pkgs.python3}/bin/python3 ${j2a} "${jsonFile}" "${title}" > $out
  '';
in
rec {
  json = moduleDocJson modules;
  adoc = jsonToAdoc "${json}/options.json";
}
