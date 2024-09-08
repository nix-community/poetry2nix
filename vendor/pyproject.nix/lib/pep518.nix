{ pep508, ... }:

{
  /*
    Parse PEP-518 `build-system.requires` from pyproject.toml.
    Type: readPyproject :: AttrSet -> list

    Example:
    # parseBuildSystems (lib.importTOML ./pyproject.toml)
      [ ]  # List of parsed PEP-508 strings as returned by `lib.pep508.parseString`.
  */
  parseBuildSystems = pyproject: map pep508.parseString (pyproject.build-system.requires or [ ]);
}
