{
  lib,
  pep440,
  pep508,
  pep518,
  ...
}:
let
  inherit (builtins)
    mapAttrs
    foldl'
    split
    filter
    ;
  inherit (lib)
    isString
    filterAttrs
    fix
    nameValuePair
    mapAttrs'
    length
    ;

  splitAttrPath = path: filter isString (split "\\." path);
  getAttrPath = path: lib.attrByPath (splitAttrPath path);

in
fix (_self: {
  /*
    Parse dependencies from pyproject.toml.

    Type: parseDependencies :: AttrSet -> AttrSet

    Example:
      # parseDependencies {
      #
      #   pyproject = (lib.importTOML ./pyproject.toml);
      #   # Don't just look at `project.optional-dependencies` for groups, also look at these:
      #   extrasAttrPaths = [ "tool.pdm.dev-dependencies" ];
      # }
      {
        dependencies = [ ];  # List of parsed PEP-508 strings (lib.pep508.parseString)
        extras = {
          dev = [ ];  # List of parsed PEP-508 strings (lib.pep508.parseString)
        };
        build-systems = [ ];  # PEP-518 build-systems (List of parsed PEP-508 strings)
      }
  */
  parseDependencies =
    {
      pyproject,
      extrasAttrPaths ? [ ],
      extrasListPaths ? { },
    }:
    let
      # Fold extras from all considered attributes into one set
      extras' =
        foldl' (acc: attr: acc // getAttrPath attr { } pyproject) (pyproject.project.optional-dependencies
          or { }
        ) extrasAttrPaths
        // filterAttrs (_: deps: length deps > 0) (
          mapAttrs' (path: attr: nameValuePair attr (getAttrPath path [ ] pyproject)) extrasListPaths
        );
    in
    {
      dependencies = map pep508.parseString (pyproject.project.dependencies or [ ]);
      extras = mapAttrs (_: map pep508.parseString) extras';
      build-systems = pep518.parseBuildSystems pyproject;
    };

  /*
    Parse project.python-requires from pyproject.toml

    Type: parseRequiresPython :: AttrSet -> list

    Example:
      #  parseRequiresPython (lib.importTOML ./pyproject.toml)
      [ ]  # List of conditions as returned by `lib.pep440.parseVersionCond`
  */
  parseRequiresPython = pyproject: pep440.parseVersionConds (pyproject.project.requires-python or "");

  /*
    Filter dependencies not relevant for this environment.

    Type: filterDependenciesByEnviron :: AttrSet -> AttrSet -> AttrSet

    Example:
      # filterDependenciesByEnviron (lib.pep508.mkEnviron pkgs.python3) (lib.pep621.parseDependencies (lib.importTOML ./pyproject.toml))
      { }  # Structure omitted in docs
  */
  filterDependenciesByEnviron =
    # Environ as created by `lib.pep508.mkEnviron`.
    environ:
    # Extras as a list of strings
    extras:
    # Dependencies as parsed by `lib.pep621.parseDependencies`.
    dependencies:
    (
      let
        environ' =
          if extras == [ ] then
            environ
          else
            environ
            // {
              extra = {
                type = "extra";
                value = extras;
              };
            };

        filterList = filter (dep: dep.markers == null || pep508.evalMarkers environ' dep.markers);
      in
      {
        dependencies = filterList dependencies.dependencies;
        extras = mapAttrs (_: filterList) dependencies.extras;
        build-systems = filterList dependencies.build-systems;
      }
    );
})
