{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, poetry ? null
,
}:

let

  importTOML = path: builtins.fromTOML (builtins.readFile path);

  getAttrDefault = attribute: set: default: (
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default
  );

  # Fetch the artifacts from the PyPI index. Since we get all
  # info we need from the lock file we don't use nixpkgs' fetchPyPi
  # as it modifies casing while not providing anything we don't already
  # have.
  #
  # Args:
  #   pname: package name
  #   file: filename including extension
  #   hash: SRI hash
  #   kind: Language implementation and version tag https://www.python.org/dev/peps/pep-0427/#file-name-convention
  fetchFromPypi = lib.makeOverridable (
    { pname, file, hash, kind }:
      pkgs.fetchurl {
        url = "https://files.pythonhosted.org/packages/${kind}/${lib.toLower (builtins.substring 0 1 file)}/${pname}/${file}";
        inherit hash;
      }
  );

  getAttrPath = attrPath: set: (
    builtins.foldl'
      (acc: v: if builtins.typeOf acc == "set" && builtins.hasAttr v acc then acc."${v}" else null)
      set (lib.splitString "." attrPath)
  );

  satisfiesSemver = (import ./semver.nix { inherit lib; }).satisfies;

  # Check Python version is compatible with package
  isCompatible = pythonVersion: pythonVersions: let
    operators = {
      "||" = cond1: cond2: cond1 || cond2;
      "," = cond1: cond2: cond1 && cond2; # , means &&
    };
    tokens = builtins.filter (x: x != "") (builtins.split "(,|\\|\\|)" pythonVersions);
  in
    (
      builtins.foldl' (
        acc: v: let
          isOperator = builtins.typeOf v == "list";
          operator = if isOperator then (builtins.elemAt v 0) else acc.operator;
        in
          if isOperator then (acc // { inherit operator; }) else {
            inherit operator;
            state = operators."${operator}" acc.state (satisfiesSemver pythonVersion v);
          }
      )
        {
          operator = ",";
          state = true;
        }
        tokens
    ).state;

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

  selectWhl = (
    import ./pep425.nix {
      inherit lib;
      inherit (pkgs) stdenv;
      python = pkgs.python3;
    }
  ).select;

  #
  # Returns the appropriate manylinux dependencies and string representation for the file specified
  #
  getManyLinuxDeps = f:
    let
      ml = pkgs.pythonManylinuxPackages;
    in
      if lib.strings.hasInfix "manylinux1" f then { pkg = [ ml.manylinux1 ]; str = "1"; }
      else if lib.strings.hasInfix "manylinux2010" f then { pkg = [ ml.manylinux2010 ]; str = "2010"; }
      else if lib.strings.hasInfix "manylinux2014" f then { pkg = [ ml.manylinux2014 ]; str = "2014"; }
      else { pkg = []; str = null; };

  mkPoetryPackage =
    { src
    , pyproject ? src + "/pyproject.toml"
    , poetrylock ? src + "/poetry.lock"
    , overrides ? defaultPoetryOverrides
    , meta ? {}
    , python ? pkgs.python3
    , ...
    }@attrs: let
      pyProject = importTOML pyproject;
      poetryLock = importTOML poetrylock;

      files = getAttrDefault "files" (getAttrDefault "metadata" poetryLock {}) {};

      specialAttrs = [ "pyproject" "poetrylock" "overrides" ];
      passedAttrs = builtins.removeAttrs attrs specialAttrs;

      evalPep508 = mkEvalPep508 python;

      poetryPkg = poetry.override { inherit python; };

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
            in
              builtins.filter (f: fileSupported f.file) all;

            filterFile = fname: builtins.match ("^.*" + builtins.replaceStrings [ "." ] [ "\\." ] pkgMeta.version + ".*$") fname != null;
            filteredFiles = builtins.filter (f: filterFile f.file) pkgFiles;

            binaryDist = selectWhl filteredFiles;
            sourceDist = builtins.filter isSdist filteredFiles;
            file = if (builtins.length sourceDist) > 0 then builtins.head sourceDist else builtins.head binaryDist;

            format =
              if isBdist file
              then "wheel"
              else "setuptools";

          in
            self.buildPythonPackage {
              pname = pkgMeta.name;
              version = pkgMeta.version;

              doCheck = false; # We never get development deps
              dontStrip = true;

              inherit format;

              nativeBuildInputs = [ pkgs.autoPatchelfHook ];
              buildInputs =  (getManyLinuxDeps file.file).pkg;
              NIX_PYTHON_MANYLINUX = (getManyLinuxDeps file.file).str;

              propagatedBuildInputs = let
                depAttrs = getAttrDefault "dependencies" pkgMeta {};
                # Some dependencies like django gets the attribute name django
                # but dependencies try to access Django
                dependencies = builtins.map (d: lib.toLower d) (builtins.attrNames depAttrs);
              in
                builtins.map getDep dependencies;

              meta = {
                broken = ! isCompatible python.version pkgMeta.python-versions;
                license = [];
              };

              src = fetchFromPypi {
                pname = pkgMeta.name;
                inherit (file) file hash;
                # We need to retrieve kind from the interpreter and the filename of the package
                # Interpreters should declare what wheel types they're compatible with (python type + ABI)
                # Here we can then choose a file based on that info.
                kind = if format == "setuptools" then "source" else (builtins.elemAt (lib.strings.splitString "-" file.file) 2);
              };
            };

          # Filter packages by their PEP508 markers
          pkgsWithFilter = builtins.map (
            pkgMeta: let
              f = if builtins.hasAttr "marker" pkgMeta then (!evalPep508 pkgMeta.marker) else false;
            in
              pkgMeta // { p2nixFiltered = f; }
          ) poetryLock.package;

          lockPkgs = builtins.map (
            pkgMeta: {
              name = pkgMeta.name;
              value = let
                drv = mkPoetryDep pkgMeta;
                override = getAttrDefault pkgMeta.name overrides (_: _: drv: drv);
              in
                if drv != null then (override self super drv) else null;
            }
          ) (builtins.filter (pkgMeta: !pkgMeta.p2nixFiltered) pkgsWithFilter);

          # Null out any filtered packages, we don't want python.pkgs from nixpkgs
          nulledPkgs = (
            builtins.listToAttrs
              (
                builtins.map (x: { name = x.name; value = null; })
                  (builtins.filter (pkgMeta: pkgMeta.p2nixFiltered) pkgsWithFilter)
              )
          );

        in
          nulledPkgs // builtins.listToAttrs lockPkgs;
      in
        python.override { inherit packageOverrides; self = py; };
      pythonPackages = py.pkgs;

      getDeps = depAttr: let
        deps = getAttrDefault depAttr pyProject.tool.poetry {};
        depAttrs = builtins.map (d: lib.toLower d) (builtins.attrNames deps);
      in
        builtins.map (dep: pythonPackages."${dep}") depAttrs;

      getInputs = attr: getAttrDefault attr attrs [];
      mkInput = attr: extraInputs: getInputs attr ++ extraInputs;

      knownBuildSystems = {
        "intreehooks:loader" = [ py.pkgs.intreehooks ];
        "poetry.masonry.api" = [ poetryPkg ];
        "" = [];
      };

      getBuildSystemPkgs = let
        buildSystem = getAttrPath
          "build-system.build-backend" pyProject;
      in
        knownBuildSystems.${buildSystem} or (throw "unsupported build system ${buildSystem}");
    in
      pythonPackages.buildPythonApplication (
        passedAttrs // {
          pname = pyProject.tool.poetry.name;
          version = pyProject.tool.poetry.version;

          format = "pyproject";

          buildInputs = mkInput "buildInputs" getBuildSystemPkgs;
          propagatedBuildInputs = mkInput "propagatedBuildInputs" (getDeps "dependencies") ++ ([ pythonPackages.setuptools ]);
          checkInputs = mkInput "checkInputs" (getDeps "dev-dependencies");

          passthru = {
            inherit pythonPackages;
            python = py;
          };

          meta = meta // {
            inherit (pyProject.tool.poetry) description;
            licenses = [ pyProject.tool.poetry.license ];
          };

        }
      );

in
{
  inherit mkPoetryPackage defaultPoetryOverrides;
}
