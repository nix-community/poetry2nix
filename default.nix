{
  pkgs ? import <nixpkgs> { },
  python ? pkgs.python3,
  pythonPackages ? python.pkgs,
}:

let

  importTOML = path: builtins.fromTOML (builtins.readFile path);

  # TODO: Because pip (and by extension poetry) supports wheels hashes are a list
  # This list has determistic but non-distinguishable origins
  # (we dont know what url the hashes corresponds to)
  #
  # Just grabbing the first possible hash only works ~50% of the time
  getSha256 = pname: poetryLock: builtins.elemAt poetryLock.metadata.hashes."${pname}" 0;

  # Note: Makes a derivation tree
  mkPoetryDerivation = {
    pname,
    depPkgs,
    pyProject,
    poetryLock,
    overrides,
  }: let
    pkgMeta = depPkgs."${pname}";
    version = pkgMeta.version;
    dependencies =
      if (builtins.hasAttr "dependencies" pkgMeta)
      then (builtins.attrNames pkgMeta.dependencies)
      else [ ];

    drv = pythonPackages.buildPythonPackage {
      inherit pname version;

      # TODO: It's probably better to model derivations as an attrset that we pick deps from
      # That way we avoid instantiating the same derivation multiple times
      propagatedBuildInputs = builtins.map (pname: (mkPoetryDerivation {
        inherit pname depPkgs pyProject poetryLock overrides;
      })) dependencies;

      doCheck = false;  # We never get development deps

      src = pythonPackages.fetchPypi {
        inherit pname version;
        sha256 = getSha256 pname poetryLock;
      };
    };

    override =
      if (builtins.hasAttr pname overrides)
      then overrides."${pname}"
      else (drv: drv);

  in override drv;

  mkPoetryPackage = {
    src,
    pyproject ? src + "/pyproject.toml",
    poetrylock ? src + "/poetry.lock",
    overrides ? import ./overrides.nix {
      inherit pkgs python pythonPackages;
    },
  }: let
    pyProject = importTOML pyproject;
    poetryLock = importTOML poetrylock;

    # Turn list of packages from lock-file into attrset for easy lookup
    depPkgs = builtins.listToAttrs (builtins.map (pkgMeta: {
      name = pkgMeta.name;
      value=pkgMeta;
    }) poetryLock.package);

    # Turn an attrset of name/version pairs into a list of derivations
    getDeps = deps: let
      depNames = builtins.filter (depName: depName != "python") (builtins.attrNames deps);
    in builtins.map (pname: mkPoetryDerivation {
      inherit pname depPkgs pyProject poetryLock overrides;
    }) depNames;

  in pythonPackages.buildPythonApplication {
    pname = pyProject.tool.poetry.name;
    version = pyProject.tool.poetry.version;

    inherit src;

    format = "pyproject";

    buildInputs = [
      pythonPackages.poetry
    ];

    propagatedBuildInputs = getDeps pyProject.tool.poetry.dependencies;
    checkInputs = getDeps pyProject.tool.poetry.dev-dependencies;

    meta = {
      description = pyProject.tool.poetry.description;
      licenses = [ pyProject.tool.poetry.license ];
    };

  };

in {
  inherit mkPoetryPackage;
}
