{ pkgs ? import <nixpkgs> {}
, lib ? pkgs.lib
, poetry ? null
, poetryLib ? import ./lib.nix { inherit lib pkgs; }
}:

let
  inherit (poetryLib) isCompatible readTOML;

  defaultPoetryOverrides = import ./overrides.nix { inherit pkgs; };

  mkEvalPep508 = import ./pep508.nix {
    inherit lib;
    stdenv = pkgs.stdenv;
  };

  getAttrDefault = attribute: set: default: (
    if builtins.hasAttr attribute set
    then builtins.getAttr attribute set
    else default
  );

  #
  # Returns an attrset { python, poetryPackages } for the given lockfile
  #
  mkPoetryPython =
    { poetrylock
    , overrides ? defaultPoetryOverrides
    , meta ? {}
    , python ? pkgs.python3
    }@attrs: let
      lockData = readTOML poetrylock;
      lockFiles = lib.getAttrFromPath [ "metadata" "files" ] lockData;

      specialAttrs = [ "poetrylock" "overrides" ];
      passedAttrs = builtins.removeAttrs attrs specialAttrs;

      evalPep508 = mkEvalPep508 python;

      # Filter packages by their PEP508 markers
      partitions = let
        supportsPythonVersion = pkgMeta: if pkgMeta ? marker then (evalPep508 pkgMeta.marker) else true;
      in
        lib.partition supportsPythonVersion lockData.package;

      compatible = partitions.right;
      incompatible = partitions.wrong;

      # Create an overriden version of pythonPackages
      #
      # We need to avoid mixing multiple versions of pythonPackages in the same
      # closure as python can only ever have one version of a dependency
      packageOverrides = self: super:
        let
          getDep = depName: if builtins.hasAttr depName self then self."${depName}" else throw "foo";

          lockPkgs = builtins.listToAttrs (
            builtins.map (
              pkgMeta: rec {
                name = pkgMeta.name;
                value = let
                  drv = self.mkPoetryDep (pkgMeta // { files = lockFiles.${name}; });
                  override = getAttrDefault pkgMeta.name overrides (_: _: drv: drv);
                in
                  override self super drv;
              }
            ) compatible
          );

          # Null out any filtered packages, we don't want python.pkgs from nixpkgs
          nulledPkgs = builtins.listToAttrs (builtins.map (x: { name = x.name; value = null; }) incompatible);
        in
          {
            mkPoetryDep = self.callPackage ./mk-poetry-dep.nix {
              inherit pkgs lib python poetryLib;
            };
          } // nulledPkgs // lockPkgs;

      py = python.override { inherit packageOverrides; self = py; };
    in {
        python = py;
        poetryPackages = map (pkg: py.pkgs.${pkg.name}) compatible;
    };

  #
  # Creates a python environment with the python packages from the specified lockfile
  #
  mkPoetryEnv =
    { poetrylock
    , overrides ? defaultPoetryOverrides
    , meta ? {}
    , python ? pkgs.python3
  }:
  let
      py = mkPoetryPython (
        {
          inherit poetrylock overrides meta python;
        }
      );
    in
      py.python.withPackages (_: py.poetryPackages);


  #
  # Creates a python application
  #
  mkPoetryApplication =
    { src
    , pyproject
    , poetrylock
    , overrides ? defaultPoetryOverrides
    , meta ? {}
    , python ? pkgs.python3
    , ...
    }@attrs: let
      poetryPkg = poetry.override { inherit python; };

      py = (mkPoetryPython {
          inherit poetrylock overrides meta python;
      }).python;

      pyProject = readTOML pyproject;

      specialAttrs = [ "pyproject" "poetrylock" "overrides" ];
      passedAttrs = builtins.removeAttrs attrs specialAttrs;

      getDeps = depAttr: let
        deps = getAttrDefault depAttr pyProject.tool.poetry {};
        depAttrs = builtins.map (d: lib.toLower d) (builtins.attrNames deps);
      in
        builtins.map (dep: py.pkgs."${dep}") depAttrs;

      getInputs = attr: getAttrDefault attr attrs [];
      mkInput = attr: extraInputs: getInputs attr ++ extraInputs;

      knownBuildSystems = {
        "intreehooks:loader" = [ py.pkgs.intreehooks ];
        "poetry.masonry.api" = [ poetryPkg ];
        "" = [];
      };

      getBuildSystemPkgs = let
        buildSystem = lib.getAttrFromPath [ "build-system" "build-backend" ] pyProject;
      in
        knownBuildSystems.${buildSystem} or (throw "unsupported build system ${buildSystem}");
    in
      py.pkgs.buildPythonApplication (
        passedAttrs // {
          pname = pyProject.tool.poetry.name;
          version = pyProject.tool.poetry.version;

          format = "pyproject";

          buildInputs = mkInput "buildInputs" getBuildSystemPkgs;
          propagatedBuildInputs = mkInput "propagatedBuildInputs" (getDeps "dependencies") ++ ([ py.pkgs.setuptools ]);
          checkInputs = mkInput "checkInputs" (getDeps "dev-dependencies");

          passthru = {
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
  inherit mkPoetryPython mkPoetryEnv mkPoetryApplication defaultPoetryOverrides;
  mkPoetryPackage = attrs: builtins.trace "mkPoetryPackage is deprecated. Use mkPoetryApplication instead." (mkPoetryApplication attrs);
}
