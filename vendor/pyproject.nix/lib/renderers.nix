{
  lib,
  pep508,
  pep440,
  pep621,
  ...
}:
let
  inherit (builtins)
    attrValues
    length
    attrNames
    head
    foldl'
    ;
  inherit (lib)
    optionalAttrs
    mapAttrs'
    mapAttrs
    filterAttrs
    concatMap
    ;

  # Group licenses by their SPDX IDs for easy lookup
  licensesBySpdxId = mapAttrs' (_: license: {
    name = license.spdxId;
    value = license;
  }) (filterAttrs (_: license: license ? spdxId) lib.licenses);

  getDependencies' =
    pythonPackages:
    concatMap (
      dep:
      let
        pkg = pythonPackages.${dep.name};
      in
      [ pkg ] ++ concatMap (extra: pkg.optional-dependencies.${extra} or [ ]) dep.extras
    );

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
      project,
      # Python derivation
      python,
      # Python extras (optionals) to enable
      extras ? [ ],
      # Extra withPackages function
      extraPackages ? _ps: [ ],
      # PEP-508 environment
      environ ? pep508.mkEnviron python,
    }:
    let
      filteredDeps = pep621.filterDependenciesByEnviron environ extras project.dependencies;
      getDependencies = getDependencies' python.pkgs;
    in
    ps:
    let
      buildSystems' =
        if filteredDeps.build-systems != [ ] then
          [ ]
        else
          [
            ps.setuptools
            ps.wheel
          ];
    in
    getDependencies filteredDeps.dependencies
    ++ attrValues (mapAttrs (_group: getDependencies) project.dependencies.extras)
    ++ getDependencies filteredDeps.build-systems
    ++ extraPackages ps
    ++ buildSystems';

  /*
    Renders a project as an argument that can be passed to buildPythonPackage/buildPythonApplication.

    Evaluates PEP-508 environment markers to select correct dependencies for the platform but does not validate version constraints.
    For validation see `lib.validators`.

    Type: buildPythonPackage :: AttrSet -> AttrSet

    Example:
      # buildPythonPackage { project = lib.project.loadPyproject ...; python = pkgs.python3;  }
        { pname = "blinker"; version = "1.3.3.7"; dependencies = [ ]; }
  */
  buildPythonPackage =
    {
      # Project metadata as returned by `lib.project.loadPyproject`
      project,
      # Python derivation
      python,
      # Python extras (markers) to enable.
      extras ? [ ],
      # Map a Python extras group name to a Nix attribute set like:
      # { dev = "checkInputs"; }
      # This is intended to be used with optionals such as test dependencies that you might
      # want to remap to checkInputs.
      extrasAttrMappings ? { },
      # Which package format to pass to buildPythonPackage
      # If the format is "wheel" PEP-518 build-systems are excluded from the build.
      format ? "pyproject",
      # PEP-508 environment
      environ ? pep508.mkEnviron python,
    #
    }:
    let
      filteredDeps = pep621.filterDependenciesByEnviron environ extras project.dependencies;

      pythonVersion = environ.python_full_version.value;

      pythonPackages = python.pkgs;
      getDependencies = getDependencies' pythonPackages;

      inherit (project) pyproject;

      meta =
        let
          project' = project.pyproject.project;
          urls = project'.urls or { };
        in
        # Optional changelog
        optionalAttrs (urls ? changelog) { inherit (urls) changelog; }
        //
          # Optional description
          optionalAttrs (project' ? description) { inherit (project') description; }
        //
          # Optional license
          optionalAttrs (project' ? license.text) (
            assert !(project'.license ? file);
            {
              # From PEP-621:
              # "The text key has a string value which is the license of the project whose meaning is that of the License field from the core metadata.
              # These keys are mutually exclusive, so a tool MUST raise an error if the metadata specifies both keys."
              # Hence the assert above.
              license = licensesBySpdxId.${project'.license.text} or project'.license.text;
            }
          )
        //
          # Only set mainProgram if we only have one script, otherwise it's ambigious which one is main
          (
            let
              scriptNames = attrNames project'.scripts;
            in
            optionalAttrs (project' ? scripts && length scriptNames == 1) { mainProgram = head scriptNames; }
          );

      optional-dependencies = lib.mapAttrs (_group: getDependencies) project.dependencies.extras;

    in
    foldl'
      (
        attrs: group:
        let
          attr = extrasAttrMappings.${group} or "dependencies";
        in
        if !extrasAttrMappings ? ${group} then
          attrs
        else
          attrs // { ${attr} = attrs.${attr} or [ ] ++ getDependencies filteredDeps.extras.${group}; }
      )
      (
        {
          pyproject = format == "pyproject";
          dependencies =
            getDependencies filteredDeps.dependencies
            # map (dep: python.pkgs.${dep}) namedDeps.dependencies
            ++ concatMap (group: optional-dependencies.${group} or [ ]) extras;
          inherit optional-dependencies meta;
        }
        // optionalAttrs (format != "pyproject") { inherit format; }
        // optionalAttrs (format != "wheel") {
          build-system =
            if filteredDeps.build-systems != [ ] then
              getDependencies filteredDeps.build-systems
            else
              [
                pythonPackages.setuptools
                pythonPackages.wheel
              ];
        }
        // optionalAttrs (pyproject.project ? name) { pname = pyproject.project.name; }
        // optionalAttrs (project.projectRoot != null) { src = project.projectRoot; }
        // optionalAttrs (pyproject.project ? version) { inherit (pyproject.project) version; }
        // optionalAttrs (project.requires-python != null) {
          disabled =
            !lib.all (spec: pep440.comparators.${spec.op} pythonVersion spec.version) project.requires-python;
        }
      )
      (attrNames filteredDeps.extras);
}
