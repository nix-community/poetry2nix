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

  defaultPoetryOverrides = import ./overrides.nix { inherit pkgs; };

  mkPoetryPackage = {
    src,
    pyproject ? src + "/pyproject.toml",
    poetrylock ? src + "/poetry.lock",
    overrides ? defaultPoetryOverrides,
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
            # Some dependencies like django gets the attribute name django
            # but dependencies try to access Django
            dependencies = builtins.map (d: lib.toLower d) (builtins.attrNames depAttrs);
          in builtins.map (dep: self."${dep}") dependencies;

          src = let
            files = getAttrDefault "files" pkgMeta [];
            files_sdist = builtins.filter (f: f.packagetype == "sdist") files;
            # Grab the first sdist, we dont care about which one
            file = assert builtins.length files_sdist >= 1; builtins.elemAt files_sdist 0;
          in self.fetchPypi {
            pname = pkgMeta.name;
            version = pkgMeta.version;
            sha256 = file.hash;
            extension = getExtension file.name;
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

    buildInputs = mkInput "buildInputs" ([ pythonPackages.poetry ]);
    propagatedBuildInputs = mkInput "propagatedBuildInputs" (getDeps "dependencies");
    checkInputs = mkInput "checkInputs" (getDeps "dev-dependencies");

    passthru = {
      inherit pythonPackages;
    };

    meta = {
      inherit (pyProject.tool.poetry) description;
      licenses = [ pyProject.tool.poetry.license ];
    };

  });

in {
  inherit mkPoetryPackage defaultPoetryOverrides;
}
