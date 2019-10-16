{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  python ? pkgs.python3,
}:

let

  importTOML = path: builtins.fromTOML (builtins.readFile path);

  getAttrDefault = attribute: set: default:
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default;

  extensions = pkgs.lib.importJSON ./extensions.json;
  getExtension = filename: builtins.elemAt
    (builtins.filter (ext: builtins.match "^.*\.${ext}" filename != null) extensions)
    0;
  supportedRe = ("^.*?(" + builtins.concatStringsSep "|" extensions + ")");
  fileSupported = fname: builtins.match supportedRe fname != null;

  defaultPoetryOverrides = import ./overrides.nix { inherit pkgs; };

  isBdist = f: builtins.match "^.*?whl$" f.file != null;
  isSdist = f: ! isBdist f;

  mkPoetryPackage = {
    src,
    pyproject ? src + "/pyproject.toml",
    poetrylock ? src + "/poetry.lock",
    overrides ? defaultPoetryOverrides,
    meta ? {},
    ...
  }@attrs: let
    pyProject = importTOML pyproject;
    poetryLock = importTOML poetrylock;

    files = getAttrDefault "files" (getAttrDefault "metadata" poetryLock {}) {};

    specialAttrs = [ "pyproject" "poetrylock" "overrides" ];
    passedAttrs = builtins.removeAttrs attrs specialAttrs;

    # Create an overriden version of pythonPackages
    #
    # We need to avoid mixing multiple versions of pythonPackages in the same
    # closure as python can only ever have one version of a dependency
    py = let
      packageOverrides = self: super: let
        mkPoetryDep = pkgMeta: let
          pkgFiles = let
            all = getAttrDefault pkgMeta.name files [];
          in builtins.filter (f: fileSupported f.file) all;

          # files = poetryLock.metadata.files;
          # files = getAttrDefault "files" pkgMeta [];
          files_sdist = builtins.filter isSdist pkgFiles;
          files_bdist = builtins.filter isBdist pkgFiles;
          files_supported = files_sdist ++ files_bdist;
          # Grab the first dist, we dont care about which one
          file = assert builtins.length files_supported >= 1; builtins.elemAt files_supported 0;

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
          in builtins.map (dep: self."${dep}") dependencies;

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

        lockPkgs = builtins.map (pkgMeta: {
          name = pkgMeta.name;
          value = let
            drv = mkPoetryDep pkgMeta;
            override = getAttrDefault pkgMeta.name overrides (_: _: drv: drv);
          in override self super drv;
        }) poetryLock.package;

      in {
        # TODO: Figure out why install check fails with overridden version
        pytest_xdist = super.pytest_xdist.overrideAttrs(old: {
          doInstallCheck = false;
        });
      } // builtins.listToAttrs lockPkgs // {
        # Temporary hacks (Missing support for markers)
        enum34 = null;
        functools32 = null;
        typing = null;
        futures = null;
      };
    in python.override { inherit packageOverrides; self = py; };
    pythonPackages = py.pkgs;

    getDeps = depAttr: let
      deps = builtins.getAttr depAttr pyProject.tool.poetry;
      depAttrs = builtins.attrNames deps;
    in builtins.map (dep: pythonPackages."${dep}") depAttrs;

    getInputs = attr: getAttrDefault attr attrs [];
    mkInput = attr: extraInputs: getInputs attr ++ extraInputs;

  in pythonPackages.buildPythonApplication (passedAttrs // {
    pname = pyProject.tool.poetry.name;
    version = pyProject.tool.poetry.version;

    format = "pyproject";

    # TODO: Only conditionally include poetry based on build-system
    # buildInputs = mkInput "buildInputs" ([ pythonPackages.poetry ]);
    buildInputs = mkInput "buildInputs" ([ pythonPackages.setuptools ]);

    propagatedBuildInputs = mkInput "propagatedBuildInputs" (getDeps "dependencies");
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
