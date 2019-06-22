{
  pkgs ? import <nixpkgs> { },
  python ? pkgs.python3,
}:

let

  importTOML = path: builtins.fromTOML (builtins.readFile path);

  # TODO: Because pip (and by extension poetry) supports wheels hashes are a list
  # This list has determistic but non-distinguishable origins
  # (we dont know what url the hashes corresponds to)
  #
  # Just grabbing the first possible hash only works ~50% of the time
  getSha256 = pname: poetryLock: builtins.elemAt poetryLock.metadata.hashes."${pname}" 0;

  defaultPoetryOverrides = import ./overrides.nix;

  mkPoetryPackage = {
    src,
    pyproject ? src + "/pyproject.toml",
    poetrylock ? src + "/poetry.lock",
    overrides ? defaultPoetryOverrides,
  }: let
    pyProject = importTOML pyproject;
    poetryLock = importTOML poetrylock;

    # Create an overriden version of pythonPackages
    #
    # We need to avoid mixing multiple versions of pythonPackages in the same
    # closure as python can only ever have one version of a dependency
    pythonPackages = (python.override {
      packageOverrides = self: super:

      let
        mkPoetryDep = pkgMeta: self.buildPythonPackage {
          pname = pkgMeta.name;
          version = pkgMeta.version;

          doCheck = false;  # We never get development deps

          propagatedBuildInputs = let
            dependencies =
              if builtins.hasAttr "dependencies" pkgMeta
              then builtins.attrNames pkgMeta.dependencies
              else [];
          in builtins.map (dep: self."${dep}") dependencies;

          src = self.fetchPypi {
            pname = pkgMeta.name;
            version = pkgMeta.version;
            sha256 = getSha256 pkgMeta.name poetryLock;
          };
        };

        lockPkgs = builtins.map (pkgMeta: {
          name = pkgMeta.name;
          value = let
            drv = mkPoetryDep pkgMeta;
            override =
              if builtins.hasAttr pkgMeta.name overrides
              then overrides."${pkgMeta.name}"
              else _: drv: drv;
          in override self drv;
        }) poetryLock.package;
      in builtins.listToAttrs lockPkgs;

    }).pkgs;

    getDeps = deps: let
      depAttrs = builtins.attrNames deps;
    in builtins.map (dep: pythonPackages."${dep}") depAttrs;

  in pythonPackages.buildPythonApplication {
    pname = pyProject.tool.poetry.name;
    version = pyProject.tool.poetry.version;

    inherit src;

    format = "pyproject";

    doCheck = false;

    buildInputs = [ pythonPackages.poetry ];

    propagatedBuildInputs = getDeps pyProject.tool.poetry.dependencies;
    checkInputs = [];  # getDeps pyProject.tool.poetry.dev-dependencies;

    meta = {
      description = pyProject.tool.poetry.description;
      licenses = [ pyProject.tool.poetry.license ];
    };

  };

in {
  inherit mkPoetryPackage defaultPoetryOverrides;
}
