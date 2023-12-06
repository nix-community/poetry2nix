{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
}:
let

  pyproject-nix = import ./vendor/pyproject.nix { inherit pkgs lib; };

  poetryLib = import ./lib.nix { inherit lib pkgs pyproject-nix; inherit (pkgs) stdenv; };
  inherit (poetryLib) readTOML;

  # Name normalization
  inherit (pyproject-nix.lib.pypa) normalizePackageName;
  normalizePackageSet = lib.attrsets.mapAttrs' (name: value: lib.attrsets.nameValuePair (normalizePackageName name) value);

  # Map SPDX identifiers to license names
  spdxLicenses = lib.listToAttrs (lib.filter (pair: pair.name != null) (builtins.map (v: { name = if lib.hasAttr "spdxId" v then v.spdxId else null; value = v; }) (lib.attrValues lib.licenses)));
  # Get license by id falling back to input string
  getLicenseBySpdxId = spdxId: spdxLicenses.${spdxId} or spdxId;

  # Experimental withPlugins functionality
  inherit ((import ./plugins.nix { inherit pkgs lib; })) toPluginAble;

  # List of known build systems that are passed through from nixpkgs unmodified
  knownBuildSystems = lib.importJSON ./known-build-systems.json;
  nixpkgsBuildSystems = lib.subtractLists [ "poetry" "poetry-core" ] knownBuildSystems;

  mkInputAttrs =
    { py
    , pyProject
    , attrs
    , includeBuildSystem ? true
    , groups ? [ ]
    , checkGroups ? [ "dev" ]
    , extras ? [ "*" ]  # * means all extras, otherwise include the dependencies for a given extra
    }:
    let
      getInputs = attr: attrs.${attr} or [ ];

      pyVersion = pyproject-nix.lib.pep440.parseVersion py.version;

      # Get dependencies and filter out depending on interpreter version
      getDeps = depSet:
        let
          depAttrs = builtins.map (d: lib.toLower d) (builtins.attrNames depSet);
        in
        builtins.map
          (
            dep:
            let
              pkg = py.pkgs."${normalizePackageName dep}";
              isCompat = poetryLib.checkPythonVersions pyVersion (depSet.${dep}.python or "");
            in
            if isCompat then pkg else null
          )
          depAttrs;

      buildSystemPkgs = poetryLib.getBuildSystemPkgs {
        inherit pyProject;
        pythonPackages = py.pkgs;
      };

      mkInput = attr: extraInputs: getInputs attr ++ extraInputs;

      rawDeps = pyProject.tool.poetry."dependencies" or { };

      rawRequiredDeps = lib.filterAttrs (_: v: !(v.optional or false)) rawDeps;

      desiredExtrasDeps = lib.unique
        (lib.concatMap (extra: pyProject.tool.poetry.extras.${extra}) extras);

      allRawDeps =
        if extras == [ "*" ] then
          rawDeps
        else
          rawRequiredDeps // lib.getAttrs desiredExtrasDeps rawDeps;
      checkInputs' = getDeps (pyProject.tool.poetry."dev-dependencies" or { })  # <poetry-1.2.0
        # >=poetry-1.2.0 dependency groups
        ++ lib.flatten (map (g: getDeps (pyProject.tool.poetry.group.${g}.dependencies or { })) checkGroups);
    in
    {
      buildInputs = mkInput "buildInputs" (if includeBuildSystem then buildSystemPkgs else [ ]);
      propagatedBuildInputs = mkInput "propagatedBuildInputs" (
        getDeps allRawDeps ++ (
          # >=poetry-1.2.0 dependency groups
          if pyProject.tool.poetry.group or { } != { }
          then lib.flatten (map (g: getDeps pyProject.tool.poetry.group.${g}.dependencies) groups)
          else [ ]
        )
      );
      nativeBuildInputs = mkInput "nativeBuildInputs" [ ];
      checkInputs = mkInput "checkInputs" checkInputs';
      nativeCheckInputs = mkInput "nativeCheckInputs" checkInputs';
    };

in
lib.makeScope pkgs.newScope (self: {
  /* Returns a package of editable sources whose changes will be available without needing to restart the
    nix-shell.
    In editablePackageSources you can pass a mapping from package name to source directory to have
    those packages available in the resulting environment, whose source changes are immediately available.

  */
  mkPoetryEditablePackage =
    { projectDir ? null
    , pyproject ? projectDir + "/pyproject.toml"
    , python ? pkgs.python3
    , pyProject ? readTOML pyproject
      # Example: { my-app = ./src; }
    , editablePackageSources
    }:
      assert editablePackageSources != { };
      import ./editable.nix {
        inherit pyProject python pkgs lib editablePackageSources;
        inherit pyproject-nix;
      };

  /* Returns a package containing scripts defined in tool.poetry.scripts.
  */
  mkPoetryScriptsPackage =
    { projectDir ? null
    , pyproject ? projectDir + "/pyproject.toml"
    , python ? pkgs.python3
    , pyProject ? readTOML pyproject
    , scripts ? pyProject.tool.poetry.scripts
    }:
      assert scripts != { };
      import ./shell-scripts.nix {
        inherit lib python scripts;
      };

  /*
    Returns an attrset { python, poetryPackages, pyProject, poetryLock } for the given pyproject/lockfile.
  */
  mkPoetryPackages =
    { projectDir ? null
    , pyproject ? projectDir + "/pyproject.toml"
    , poetrylock ? projectDir + "/poetry.lock"
    , poetrylockPos ? { file = toString poetrylock; line = 0; column = 0; }
    , overrides ? self.defaultPoetryOverrides
    , python ? pkgs.python3
    , pwd ? projectDir
    , preferWheels ? false
      # Example: { my-app = ./src; }
    , editablePackageSources ? { }
    , pyProject ? readTOML pyproject
    , groups ? [ ]
    , checkGroups ? [ "dev" ]
    , extras ? [ "*" ]
    }:
    let
      getFunctorFn = fn: if builtins.typeOf fn == "set" then fn.__functor else fn;

      scripts = pyProject.tool.poetry.scripts or { };
      hasScripts = scripts != { };
      scriptsPackage = self.mkPoetryScriptsPackage {
        inherit python scripts;
      };

      editablePackageSources' = lib.filterAttrs (_name: path: path != null) editablePackageSources;
      hasEditable = editablePackageSources' != { };
      editablePackage = self.mkPoetryEditablePackage {
        inherit pyProject python;
        editablePackageSources = editablePackageSources';
      };

      poetryLock = readTOML poetrylock;

      # Lock file version 1.1 files
      lockFiles =
        let
          lockfiles = lib.getAttrFromPath [ "metadata" "files" ] poetryLock;
        in
        lib.listToAttrs (lib.mapAttrsToList (n: v: { name = normalizePackageName n; value = v; }) lockfiles);

      pep508Env = pyproject-nix.lib.pep508.mkEnviron python;

      pyVersion = pyproject-nix.lib.pep440.parseVersion python.version;

      # Filter packages by their PEP508 markers & pyproject interpreter version
      partitions =
        let
          supportsPythonVersion = pkgMeta:
            if pkgMeta ? marker then
              (
                let
                  marker = pyproject-nix.lib.pep508.parseMarkers pkgMeta.marker;
                in
                pyproject-nix.lib.pep508.evalMarkers pep508Env marker
              ) else true && poetryLib.checkPythonVersions pyVersion pkgMeta.python-versions;
        in
        lib.partition supportsPythonVersion poetryLock.package;
      compatible = partitions.right;
      incompatible = partitions.wrong;

      # Create an overridden version of pythonPackages
      #
      # We need to avoid mixing multiple versions of pythonPackages in the same
      # closure as python can only ever have one version of a dependency
      baseOverlay = self: super:
        let
          lockPkgs = builtins.listToAttrs (
            builtins.map
              (
                pkgMeta:
                let normalizedName = normalizePackageName pkgMeta.name; in
                {
                  name = normalizedName;
                  value = self.mkPoetryDep (
                    pkgMeta // {
                      inherit pwd preferWheels;
                      pos = poetrylockPos;
                      source = pkgMeta.source or null;
                      # Default to files from lock file version 2.0 and fall back to 1.1
                      files = pkgMeta.files or lockFiles.${normalizedName};
                      pythonPackages = self;

                      sourceSpec = (normalizePackageSet pyProject.tool.poetry.dependencies or { }).${normalizedName}
                        or (normalizePackageSet pyProject.tool.poetry.dev-dependencies or { }).${normalizedName}
                        or (normalizePackageSet pyProject.tool.poetry.group.dev.dependencies or { }).${normalizedName} # Poetry 1.2.0+
                        or { };
                    }
                  );
                }
              )
              (lib.reverseList compatible)
          );
          buildSystems = builtins.listToAttrs (builtins.map (x: { name = x; value = super.${x}; }) nixpkgsBuildSystems);
        in
        lockPkgs // buildSystems // {
          # Create a dummy null package for the current project in case any dependencies depend on the root project (issue #307)
          ${pyProject.tool.poetry.name} = null;
        };
      overlays = builtins.map
        getFunctorFn
        (
          [
            (self: super: lib.attrsets.mapAttrs
              (
                name: value:
                  if lib.isDerivation value && self.hasPythonModule value && (normalizePackageName name) != name
                  then null
                  else value
              )
              super)

            (
              self: _super:
                {
                  mkPoetryDep = self.callPackage ./mk-poetry-dep.nix {
                    inherit lib python poetryLib pep508Env pyVersion;
                    inherit pyproject-nix;
                  };

                  __toPluginAble = toPluginAble self;
                }
            )

            # Fix infinite recursion in a lot of packages because of checkInputs
            (_self: super: lib.mapAttrs
              (_name: value: (
                if lib.isDerivation value && lib.hasAttr "overridePythonAttrs" value
                then value.overridePythonAttrs (_: { doCheck = false; })
                else value
              ))
              super)

            # Null out any filtered packages, we don't want python.pkgs from nixpkgs
            (_self: _super: builtins.listToAttrs (builtins.map (x: { name = normalizePackageName x.name; value = null; }) incompatible))
            # Create poetry2nix layer
            baseOverlay

          ] ++ # User provided overrides
          (if builtins.typeOf overrides == "list" then overrides else [ overrides ])
        );
      packageOverrides = lib.foldr lib.composeExtensions (_self: _super: { }) overlays;
      py = python.override { inherit packageOverrides; self = py; };

      inputAttrs = mkInputAttrs { inherit py pyProject groups checkGroups extras; attrs = { }; includeBuildSystem = false; };

      inherit (python.pkgs) requiredPythonModules;
      /* Include all the nested dependencies which are required for each package.
        This guarantees that using the "poetryPackages" attribute will return
        complete list of dependencies for the poetry project to be portable.
      */
      storePackages = requiredPythonModules (builtins.foldl' (acc: v: acc ++ v) [ ] (lib.attrValues inputAttrs));
    in
    {
      python = py;
      poetryPackages = storePackages
        ++ lib.optional hasScripts scriptsPackage
        ++ lib.optional hasEditable editablePackage;
      inherit poetryLock;
      inherit pyProject;
    };

  /* Returns a package with a python interpreter and all packages specified in the poetry.lock lock file.
    In editablePackageSources you can pass a mapping from package name to source directory to have
    those packages available in the resulting environment, whose source changes are immediately available.

    Example:
    poetry2nix.mkPoetryEnv { poetrylock = ./poetry.lock; python = python3; }
  */
  mkPoetryEnv =
    { projectDir ? null
    , pyproject ? projectDir + "/pyproject.toml"
    , poetrylock ? projectDir + "/poetry.lock"
    , overrides ? self.defaultPoetryOverrides
    , pwd ? projectDir
    , python ? pkgs.python3
    , preferWheels ? false
    , editablePackageSources ? { }
    , extraPackages ? _ps: [ ]
    , groups ? [ "dev" ]
    , checkGroups ? [ "dev" ]
    , extras ? [ "*" ]
    }:
    let
      inherit (lib) hasAttr;

      pyProject = readTOML pyproject;

      # Automatically add dependencies with develop = true as editable packages, but only if path dependencies
      getEditableDeps = set: lib.mapAttrs
        (_name: value: projectDir + "/${value.path}")
        (lib.filterAttrs (_name: dep: dep.develop or false && hasAttr "path" dep) set);

      excludedEditablePackageNames = builtins.filter
        (pkg: editablePackageSources."${pkg}" == null)
        (builtins.attrNames editablePackageSources);

      allEditablePackageSources = (getEditableDeps (pyProject.tool.poetry."dependencies" or { }))
        // (getEditableDeps (pyProject.tool.poetry."dev-dependencies" or { }))
        // (
        # Poetry>=1.2.0
        if pyProject.tool.poetry.group or { } != { } then
          builtins.foldl' (acc: g: acc // getEditableDeps pyProject.tool.poetry.group.${g}.dependencies) { } groups
        else { }
      )
        // editablePackageSources;

      editablePackageSources' = builtins.removeAttrs
        allEditablePackageSources
        excludedEditablePackageNames;

      poetryPython = self.mkPoetryPackages {
        inherit pyproject poetrylock overrides python pwd preferWheels pyProject groups checkGroups extras;
        editablePackageSources = editablePackageSources';
      };

      inherit (poetryPython) poetryPackages;

      # Don't add editable sources to the environment since they will sometimes fail to build and are not useful in the development env
      editableAttrs = lib.attrNames editablePackageSources';
      envPkgs = builtins.filter (drv: ! lib.elem (drv.pname or drv.name or "") editableAttrs) poetryPackages;

    in
    poetryPython.python.withPackages (ps: envPkgs ++ (extraPackages ps));

  /* Creates a Python application from pyproject.toml and poetry.lock

    The result also contains a .dependencyEnv attribute which is a python
    environment of all dependencies and this apps modules. This is useful if
    you rely on dependencies to invoke your modules for deployment: e.g. this
    allows `gunicorn my-module:app`.
  */
  mkPoetryApplication =
    { projectDir ? null
    , src ? (
        # Assume that a project which is the result of a derivation is already adequately filtered
        if lib.isDerivation projectDir then projectDir else self.cleanPythonSources { src = projectDir; }
      )
    , pyproject ? projectDir + "/pyproject.toml"
    , poetrylock ? projectDir + "/poetry.lock"
    , overrides ? self.defaultPoetryOverrides
    , meta ? { }
    , python ? pkgs.python3
    , pwd ? projectDir
    , preferWheels ? false
    , groups ? [ ]
    , checkGroups ? [ "dev" ]
    , extras ? [ "*" ]
    , ...
    }@attrs:
    let
      poetryPython = self.mkPoetryPackages {
        inherit pyproject poetrylock overrides python pwd preferWheels groups checkGroups extras;
      };
      py = poetryPython.python;

      hooks = py.pkgs.callPackage ./hooks { };

      inherit (poetryPython) pyProject;
      specialAttrs = [
        "overrides"
        "poetrylock"
        "projectDir"
        "pwd"
        "pyproject"
        "preferWheels"
      ];
      passedAttrs = builtins.removeAttrs attrs specialAttrs;

      inputAttrs = mkInputAttrs { inherit py pyProject attrs groups checkGroups extras; };

      app = py.pkgs.buildPythonPackage (
        passedAttrs // inputAttrs // {
          nativeBuildInputs = inputAttrs.nativeBuildInputs ++ [
            hooks.removePathDependenciesHook
            hooks.removeGitDependenciesHook
            hooks.removeWheelUrlDependenciesHook
          ];
        } // {
          pname = normalizePackageName pyProject.tool.poetry.name;
          inherit (pyProject.tool.poetry) version;

          inherit src;

          format = "pyproject";
          # Like buildPythonApplication, but without the toPythonModule part
          # Meaning this ends up looking like an application but it also
          # provides python modules
          namePrefix = "";

          passthru = {
            python = py;
            dependencyEnv = (
              lib.makeOverridable ({ app, ... }@attrs:
                let
                  args = builtins.removeAttrs attrs [ "app" ] // {
                    extraLibs = [ app ];
                  };
                in
                py.buildEnv.override args)
            ) { inherit app; };
          };

          # Extract position from explicitly passed attrs so meta.position won't point to poetry2nix internals
          pos = builtins.unsafeGetAttrPos (lib.elemAt (lib.attrNames attrs) 0) attrs;

          meta = lib.optionalAttrs (lib.hasAttr "description" pyProject.tool.poetry)
            {
              inherit (pyProject.tool.poetry) description;
            } // lib.optionalAttrs (lib.hasAttr "homepage" pyProject.tool.poetry) {
            inherit (pyProject.tool.poetry) homepage;
          } // {
            inherit (py.meta) platforms;
            license = getLicenseBySpdxId (pyProject.tool.poetry.license or "unknown");
          } // meta;

        }
      );
    in
    app;

  /* Poetry2nix CLI used to supplement SHA-256 hashes for git dependencies  */
  cli = import ./cli.nix {
    inherit pkgs lib;
  };

  # inherit mkPoetryEnv mkPoetryApplication mkPoetryPackages;

  inherit (poetryLib) cleanPythonSources;


  /*
    Create a new default set of overrides with the same structure as the built-in ones
  */
  mkDefaultPoetryOverrides = defaults: {
    __functor = defaults;

    extend = overlay:
      let
        composed = lib.foldr lib.composeExtensions overlay [ defaults ];
      in
      self.mkDefaultPoetryOverrides composed;

    overrideOverlay = fn:
      let
        overlay = self: super:
          let
            defaultSet = defaults self super;
            customSet = fn self super;
          in
          defaultSet // customSet;
      in
      self.mkDefaultPoetryOverrides overlay;
  };

  /*
    The default list of poetry2nix override overlays

    Can be overriden by calling defaultPoetryOverrides.overrideOverlay which takes an overlay function
  */
  defaultPoetryOverrides = self.mkDefaultPoetryOverrides (import ./overrides { inherit pkgs lib; });

  /*
    Convenience functions for specifying overlays with or without the poerty2nix default overrides
  */
  overrides = {
    /*
      Returns the specified overlay in a list
    */
    withoutDefaults = overlay: [
      overlay
    ];

    /*
      Returns the specified overlay and returns a list
      combining it with poetry2nix default overrides
    */
    withDefaults = overlay: [
      overlay
      self.defaultPoetryOverrides
    ];
  };
})
