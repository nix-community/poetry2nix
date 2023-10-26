{ lib
, pep508
, pep621
, ...
}:
let
  inherit (builtins) attrValues length attrNames head foldl';
  inherit (lib) optionalAttrs flatten mapAttrs' filterAttrs;

  # Group licenses by their SPDX IDs for easy lookup
  licensesBySpdxId = mapAttrs'
    (_: license: {
      name = license.spdxId;
      value = license;
    })
    (filterAttrs (_: license: license ? spdxId) lib.licenses);

in
{
  /*
    Renders a project as an argument that can be passed to withPackages

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.
    For validation see `lib.validators`.

    Type: withPackages :: AttrSet -> lambda

    Example:
      # withPackages (lib.project.loadPyproject { ... })
        «lambda @ «string»:1:1»
    */
  withPackages =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project
    , # Python derivation
      python
    , # Python extras (optionals) to enable
      extras ? [ ]
    ,
    }:
    let
      filteredDeps = pep621.filterDependencies {
        inherit (project) dependencies;
        environ = pep508.mkEnviron python;
        inherit extras;
      };
      namedDeps = pep621.getDependenciesNames filteredDeps;
      flatDeps = namedDeps.dependencies ++ flatten (attrValues namedDeps.extras) ++ namedDeps.build-systems;
    in
    ps: map (dep: ps.${dep}) flatDeps;

  /*
    Renders a project as an argument that can be passed to buildPythonPackage/buildPythonApplication.

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.
    For validation see `lib.validators`.

    Type: buildPythonPackage :: AttrSet -> AttrSet

    Example:
      # buildPythonPackage { project = lib.project.loadPyproject ...; python = pkgs.python3;  }
        { pname = "blinker"; version = "1.3.3.7"; propagatedBuildInputs = [ ]; }
    */
  buildPythonPackage =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project
    , # Python derivation
      python
    , # Python extras (optionals) to enable
      extras ? [ ]
    , # Map a Python extras group name to a Nix attribute set.
      # This is intended to be used with optionals such as test dependencies that you might
      # want to add to checkInputs instead of propagatedBuildInputs
      extrasAttrMappings ? { }
    , # Which package format to pass to buildPythonPackage
      # If the format is "wheel" PEP-518 build-systems are excluded from the build.
      format ? "pyproject"
    }:
    let
      filteredDeps = pep621.filterDependencies {
        inherit (project) dependencies;
        environ = pep508.mkEnviron python;
        inherit extras;
      };

      namedDeps = pep621.getDependenciesNames filteredDeps;

      inherit (project) pyproject;

      meta =
        let
          project' = project.pyproject.project;
          urls = project'.urls or { };
        in
        # Optional changelog
        optionalAttrs (urls ? changelog)
          {
            inherit (urls) changelog;
          } //
        # Optional description
        optionalAttrs (project' ? description) {
          inherit (project') description;
        } //
        # Optional license
        optionalAttrs (project'.license ? text) (
          assert !(project'.license ? file); {
            # From PEP-621:
            # "The text key has a string value which is the license of the project whose meaning is that of the License field from the core metadata.
            # These keys are mutually exclusive, so a tool MUST raise an error if the metadata specifies both keys."
            # Hence the assert above.
            license = licensesBySpdxId.${project'.license.text};
          }
        ) //
        # Only set mainProgram if we only have one script, otherwise it's ambigious which one is main
        (
          let
            scriptNames = attrNames project'.scripts;
          in
          optionalAttrs (project' ? scripts && length scriptNames == 1) {
            mainProgram = head scriptNames;
          }
        );

    in
    foldl'
      (attrs: group:
      let
        attr = extrasAttrMappings.${group} or "propagatedBuildInputs";
      in
      attrs // {
        ${attr} = attrs.${attr} or [ ] ++ map (dep: python.pkgs.${dep}) namedDeps.extras.${group};
      })
      ({
        propagatedBuildInputs = map (dep: python.pkgs.${dep}) namedDeps.dependencies;
        inherit format meta;
      } // optionalAttrs (format != "wheel") {
        nativeBuildInputs = map (dep: python.pkgs.${dep}) namedDeps.build-systems;
      } // optionalAttrs (pyproject.project ? name) {
        pname = pyproject.project.name;
      }
      // optionalAttrs (pyproject.project ? version) {
        inherit (pyproject.project) version;
      })
      (attrNames namedDeps.extras);
}
