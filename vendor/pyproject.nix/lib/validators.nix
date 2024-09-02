{
  lib,
  pep440,
  pep508,
  pep621,
  pypa,
  ...
}:
let
  inherit (builtins) attrValues foldl' filter;
  inherit (lib) concatLists;

in
{
  /*
    Validates the Python package set held by Python (`python.pkgs`) against the parsed project.

    Returns an attribute set where the name is the Python package derivation `pname` and the value is a list of the mismatching conditions.

    Type: validateVersionConstraints :: AttrSet -> AttrSet

    Example:
      # validateVersionConstraints (lib.project.loadPyproject { ... })
      {
        resolvelib = {
          # conditions as returned by `lib.pep440.parseVersionCond`
          conditions = [ { op = ">="; version = { dev = null; epoch = 0; local = null; post = null; pre = null; release = [ 1 0 1 ]; }; } ];
          # Version from Python package set
          version = "0.5.5";
        };
        unearth = {
          conditions = [ { op = ">="; version = { dev = null; epoch = 0; local = null; post = null; pre = null; release = [ 0 10 0 ]; }; } ];
          version = "0.9.1";
        };
      }
  */
  validateVersionConstraints =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project,
      # Python derivation
      python,
      # Python extras (optionals) to enable
      extras ? [ ],
    }:
    let
      environ = pep508.mkEnviron python;
      filteredDeps = pep621.filterDependenciesByEnviron environ [ ] project.dependencies;
      flatDeps =
        filteredDeps.dependencies
        ++ concatLists (attrValues filteredDeps.extras)
        ++ filteredDeps.build-systems;

    in
    foldl' (
      acc: dep:
      let
        pname = pypa.normalizePackageName dep.name;
        pversion = python.pkgs.${pname}.version;
        version = pep440.parseVersion python.pkgs.${pname}.version;
        incompatible = filter (cond: !pep440.comparators.${cond.op} version cond.version) dep.conditions;
      in
      if incompatible == [ ] then
        acc
      else
        acc
        // {
          ${pname} = {
            version = pversion;
            conditions = incompatible;
          };
        }
    ) { } flatDeps;
}
