{
  pkgs ? import <nixpkgs> { },
  python ? pkgs.python3,
}:

let

  importTOML = path: builtins.fromTOML (builtins.readFile path);

  getAttrDefault = attribute: set: default:
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default;

  defaultPoetryOverrides = import ./overrides.nix { inherit pkgs; };

  mkPoetryPackage = {
    src,
    pyproject ? src + "/pyproject.toml",
    poetrylock ? src + "/poetry.lock",
    overrides ? defaultPoetryOverrides,
    buildInputs ? [ ],
    checkInputs ? [ ],
    propagatedBuildInputs ? [ ],
    ...
  }@attrs: let
    pyProject = importTOML pyproject;
    poetryLock = importTOML poetrylock;

    specialAttrs = [ "pyproject" "poetrylock" "overrides" ];
    passedAttrs = builtins.removeAttrs attrs specialAttrs;

    # Create an overriden version of pythonPackages
    #
    # We need to avoid mixing multiple versions of pythonPackages in the same
    # closure as python can only ever have one version of a dependency
    pythonPackages = (python.override {
      packageOverrides = self: super: let

        mkPoetryDep = pkgMeta: self.buildPythonPackage {
          pname = pkgMeta.name;
          version = pkgMeta.version;

          doCheck = false;  # We never get development deps

          propagatedBuildInputs = let
            depAttrs = getAttrDefault "dependencies" pkgMeta {};
            dependencies = builtins.attrNames depAttrs;
          in builtins.map (dep: self."${dep}") dependencies;

          src = let
            files = getAttrDefault "files" pkgMeta [];
            files_sdist = builtins.filter (f: f.packagetype == "sdist") files;
            files_tar = builtins.filter (f: (builtins.match "^.*?tar.gz$" f.name) != null) files_sdist;
            file = assert builtins.length files_tar == 1; builtins.elemAt files_tar 0;
          in self.fetchPypi {
            pname = pkgMeta.name;
            version = pkgMeta.version;
            sha256 = file.hash;
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
      };

    }).pkgs;

    getDeps = deps: let
      depAttrs = builtins.attrNames deps;
    in builtins.map (dep: pythonPackages."${dep}") depAttrs;

  in pythonPackages.buildPythonApplication (passedAttrs // {
    pname = pyProject.tool.poetry.name;
    version = pyProject.tool.poetry.version;

    format = "pyproject";

    buildInputs = [ pythonPackages.poetry ]
      ++ buildInputs;

    propagatedBuildInputs = getDeps pyProject.tool.poetry.dependencies
      ++ propagatedBuildInputs;

    checkInputs = getDeps pyProject.tool.poetry.dev-dependencies
      ++ checkInputs;

    meta = {
      description = pyProject.tool.poetry.description;
      licenses = [ pyProject.tool.poetry.license ];
    };

  });

in {
  inherit mkPoetryPackage defaultPoetryOverrides;
}
