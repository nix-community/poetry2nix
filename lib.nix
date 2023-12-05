{ lib, pyproject-nix, pkgs, ... }:
let
  inherit (import ./vendor/pyproject.nix/lib/util.nix { inherit lib; }) splitComma;

  fromTOML = builtins.fromTOML or
    (
      toml: builtins.fromJSON (
        builtins.readFile (
          pkgs.runCommand "from-toml"
            {
              inherit toml;
              allowSubstitutes = false;
              preferLocalBuild = true;
            }
            ''
              ${pkgs.remarshal}/bin/remarshal \
                -if toml \
                -i <(echo "$toml") \
                -of json \
                -o $out
            ''
        )
      )
    );
  readTOML = path: fromTOML (builtins.readFile path);

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
    else if lib.strings.hasInfix "manylinux_" f then { pkg = [ ml.manylinux2014 ]; str = "pep600"; }
    else { pkg = [ ]; str = null; };

  getBuildSystemPkgs =
    { pythonPackages
    , pyProject
    }:
    let
      missingBuildBackendError = "No build-system.build-backend section in pyproject.toml. "
        + "Add such a section as described in https://python-poetry.org/docs/pyproject/#poetry-and-pep-517";
      requires = lib.attrByPath [ "build-system" "requires" ] (throw missingBuildBackendError) pyProject;
      requiredPkgs = builtins.map (n: (pyproject-nix.lib.pep508.parseString n).name) requires;
    in
    builtins.map (drvAttr: pythonPackages.${drvAttr} or (throw "unsupported build system requirement ${drvAttr}")) requiredPkgs;

  # Find gitignore files recursively in parent directory stopping with .git
  findGitIgnores = path:
    let
      parent = path + "/..";
      gitIgnore = path + "/.gitignore";
      isGitRoot = builtins.pathExists (path + "/.git");
      hasGitIgnore = builtins.pathExists gitIgnore;
      gitIgnores = if hasGitIgnore then [ gitIgnore ] else [ ];
    in
    lib.optionals (builtins.pathExists path && builtins.toString path != "/" && ! isGitRoot) (findGitIgnores parent) ++ gitIgnores;

  /*
    Provides a source filtering mechanism that:

    - Filters gitignore's
    - Filters pycache/pyc files
    - Uses cleanSourceFilter to filter out .git/.hg, .o/.so, editor backup files & nix result symlinks
  */
  cleanPythonSources = { src }:
    let
      gitIgnores = findGitIgnores src;
      pycacheFilter = name: type:
        (type == "directory" && ! lib.strings.hasInfix "__pycache__" name)
        || (type == "regular" && ! lib.strings.hasSuffix ".pyc" name)
      ;
    in
    lib.cleanSourceWith {
      filter = lib.cleanSourceFilter;
      src = lib.cleanSourceWith {
        filter = pkgs.nix-gitignore.gitignoreFilterPure pycacheFilter gitIgnores src;
        inherit src;
      };
    };

  checkPythonVersions = pyVersion: python-versions: (
    lib.any
      (python-versions': lib.all
        (cond:
          let
            conds = pyproject-nix.lib.poetry.parseVersionCond cond;
          in
          lib.all (cond': pyproject-nix.lib.pep440.comparators.${cond'.op} pyVersion cond'.version) conds)
        (splitComma python-versions'))
      (builtins.filter lib.isString (builtins.split " *\\|\\| *" python-versions)));

in
{
  inherit
    getManyLinuxDeps
    readTOML
    getBuildSystemPkgs
    cleanPythonSources
    checkPythonVersions
    ;
}
