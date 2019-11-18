{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
}:

let

  importTOML = path: builtins.fromTOML (builtins.readFile path);

  getAttrDefault = attribute: set: default: (
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default
  );

  getAttrPathDefault = attrPath: set: default: (
    builtins.foldl'
    (acc: v: if builtins.hasAttr v acc then acc."${v}" else default)
    set (lib.splitString "." attrPath)
  );

  satisfiesSemver = (import ./semver.nix {inherit lib;}).satisfies;

  # Check Python version is compatible with package
  isCompatible = pythonVersion: pythonVersions: let
    operators = {
      "||" = cond1: cond2: cond1 || cond2;
      "," = cond1: cond2: cond1 && cond2;  # , means &&
    };
    tokens = builtins.filter (x: x != "") (builtins.split "(,|\\|\\|)" pythonVersions);
  in (builtins.foldl' (acc: v: let
    isOperator = builtins.typeOf v == "list";
    operator = if isOperator then (builtins.elemAt v 0) else acc.operator;
  in if isOperator then (acc // {inherit operator;}) else {
    inherit operator;
    state = operators."${operator}" acc.state (satisfiesSemver pythonVersion v);
  })
  {
    operator = ",";
    state = true;
  }
  tokens).state;

  extensions = pkgs.lib.importJSON ./extensions.json;
  getExtension = filename: builtins.elemAt
    (builtins.filter (ext: builtins.match "^.*\.${ext}" filename != null) extensions)
    0;
  supportedRe = ("^.*?(" + builtins.concatStringsSep "|" extensions + ")");
  fileSupported = fname: builtins.match supportedRe fname != null;

  defaultPoetryOverrides = import ./overrides.nix { inherit pkgs; };

  isBdist = f: builtins.match "^.*?whl$" f.file != null;
  isSdist = f: ! isBdist f;

  mkEvalPep508 = import ./pep508.nix {
    inherit lib;
    stdenv = pkgs.stdenv;
  };

  mkPoetryPackage = {
    src,
    pyproject ? src + "/pyproject.toml",
    poetrylock ? src + "/poetry.lock",
    overrides ? defaultPoetryOverrides,
    meta ? {},
    python ? pkgs.python3,
    ...
  }@attrs: let
    pyProject = importTOML pyproject;
    poetryLock = importTOML poetrylock;

    files = getAttrDefault "files" (getAttrDefault "metadata" poetryLock {}) {};

    specialAttrs = [ "pyproject" "poetrylock" "overrides" ];
    passedAttrs = builtins.removeAttrs attrs specialAttrs;

    evalPep508 = mkEvalPep508 python;

    # Create an overriden version of pythonPackages
    #
    # We need to avoid mixing multiple versions of pythonPackages in the same
    # closure as python can only ever have one version of a dependency
    py = let
      packageOverrides = self: super: let
        getDep = depName: if builtins.hasAttr depName self then self."${depName}" else null;

        mkPoetryDep = pkgMeta: let
          pkgFiles = let
            all = getAttrDefault pkgMeta.name files [];
          in builtins.filter (f: fileSupported f.file) all;

          files_sdist = builtins.filter isSdist pkgFiles;
          files_bdist = builtins.filter isBdist pkgFiles;
          files_supported = files_sdist ++ files_bdist;
          # Only files matching this version
          filterFile = fname: builtins.match ("^.*" + builtins.replaceStrings [ "." ] [ "\\." ] pkgMeta.version + ".*$") fname != null;
          files_filtered = builtins.filter (f: filterFile f.file) files_supported;
          # Grab the first dist, we dont care about which one
          file = assert builtins.length files_filtered >= 1; builtins.elemAt files_filtered 0;

          format =
            if isBdist file
            then "wheel"
            else "setuptools";

        in self.buildPythonPackage {
          pname = pkgMeta.name;
          version = pkgMeta.version;

          doCheck = false;  # We never get development deps

          inherit format;

          propagatedBuildInputs = let
            depAttrs = getAttrDefault "dependencies" pkgMeta {};
            # Some dependencies like django gets the attribute name django
            # but dependencies try to access Django
            dependencies = builtins.map (d: lib.toLower d) (builtins.attrNames depAttrs);
          in builtins.map getDep dependencies;

          meta = {
            broken = ! isCompatible python.version pkgMeta.python-versions;
          };

          src =
            if format == "wheel"
            then self.fetchPypi {
              pname = pkgMeta.name;
              version = pkgMeta.version;
              sha256 = file.hash;
              format = "wheel";
            }
            else self.fetchPypi {
              pname = pkgMeta.name;
              version = pkgMeta.version;
              sha256 = file.hash;
              extension = getExtension file.file;
            };

        };

        # Filter packages by their PEP508 markers
        pkgsWithFilter = builtins.map (pkgMeta: let
          f = if builtins.hasAttr "marker" pkgMeta then (!evalPep508 pkgMeta.marker) else false;
        in pkgMeta // { p2nixFiltered = f; }) poetryLock.package;

        lockPkgs = builtins.map (pkgMeta: {
          name = pkgMeta.name;
          value = let
            drv = mkPoetryDep pkgMeta;
            override = getAttrDefault pkgMeta.name overrides (_: _: drv: drv);
          in if drv != null then (override self super drv) else null;
        }) (builtins.filter (pkgMeta: !pkgMeta.p2nixFiltered) pkgsWithFilter);

        # Null out any filtered packages, we don't want python.pkgs from nixpkgs
        nulledPkgs = (
          builtins.listToAttrs
          (builtins.map (x: { name = x.name; value = null; })
          (builtins.filter (pkgMeta: pkgMeta.p2nixFiltered) pkgsWithFilter)));

      in nulledPkgs // builtins.listToAttrs lockPkgs;
    in python.override { inherit packageOverrides; self = py; };
    pythonPackages = py.pkgs;

    getDeps = depAttr: let
      deps = builtins.getAttr depAttr pyProject.tool.poetry;
      depAttrs = builtins.attrNames deps;
    in builtins.map (dep: pythonPackages."${dep}") depAttrs;

    getInputs = attr: getAttrDefault attr attrs [];
    mkInput = attr: extraInputs: getInputs attr ++ extraInputs;

    hasPoetryBuildSystem = getAttrPathDefault "build-system.build-backend" pyProject null == "poetry.masonry.api";

  in pythonPackages.buildPythonApplication (passedAttrs // {
    pname = pyProject.tool.poetry.name;
    version = pyProject.tool.poetry.version;

    format = "pyproject";

    buildInputs = mkInput "buildInputs" (lib.optional hasPoetryBuildSystem pythonPackages.poetry);

    propagatedBuildInputs = mkInput "propagatedBuildInputs" (getDeps "dependencies") ++ ([ pythonPackages.setuptools ]);
    checkInputs = mkInput "checkInputs" (getDeps "dev-dependencies");

    passthru = {
      inherit pythonPackages;
    };

    meta = meta // {
      inherit (pyProject.tool.poetry) description;
      licenses = [ pyProject.tool.poetry.license ];
    };

  });

in {
  inherit mkPoetryPackage defaultPoetryOverrides;
}
