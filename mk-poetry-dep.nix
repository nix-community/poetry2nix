{ autoPatchelfHook
, lib
, python
, buildPythonPackage
, poetryLib
, pep508Env
, pyVersion
, pyproject-nix
}:
{ name
, version
, pos ? __curPos
, extras ? [ ]
, files
, source
, dependencies ? { }
, pythonPackages
, python-versions
, pwd
, sourceSpec
, supportedExtensions ? lib.importJSON ./extensions.json
, preferWheels ? false
, ...
}:

let
  inherit (pyproject-nix.lib) pypa;

  selectWheel = files: lib.take 1 (let
    wheelFiles = builtins.filter (fileEntry: pypa.isWheelFileName fileEntry.file) files;
    # Group wheel files by their file name
    wheelFilesByFileName = lib.listToAttrs (map (fileEntry: lib.nameValuePair fileEntry.file fileEntry) wheelFiles);
    selectedWheels = pypa.selectWheels python.stdenv.targetPlatform python (map (fileEntry: pypa.parseWheelFileName fileEntry.file) wheelFiles);
  in map (wheel: wheelFilesByFileName.${wheel.filename}) selectedWheels);

in

pythonPackages.callPackage
  (
    { preferWheel ? preferWheels
    , ...
    }@args:
    let
      inherit (pyproject-nix.lib.pypa) normalizePackageName;
      inherit (poetryLib) getManyLinuxDeps;

      fileCandidates =
        let
          supportedRegex = "^.*(" + builtins.concatStringsSep "|" supportedExtensions + ")";
          matchesVersion = fname: builtins.match ("^.*" + builtins.replaceStrings [ "." "+" ] [ "\\." "\\+" ] version + ".*$") fname != null;
          hasSupportedExtension = fname: builtins.match supportedRegex fname != null;
          isCompatibleEgg = fname: ! lib.strings.hasSuffix ".egg" fname || lib.strings.hasSuffix "py${python.pythonVersion}.egg" fname;
        in
        builtins.filter (f: matchesVersion f.file && hasSupportedExtension f.file && isCompatibleEgg f.file) files;

      isLocked = lib.length fileCandidates > 0;
      isSource = source != null;
      isGit = isSource && source.type == "git";
      isUrl = isSource && source.type == "url";
      isWheelUrl = isSource && source.type == "url" && lib.strings.hasSuffix ".whl" source.url;
      isDirectory = isSource && source.type == "directory";
      isFile = isSource && source.type == "file";
      isLegacy = isSource && source.type == "legacy";
      localDepPath = pwd + "/${source.url}";

      buildSystemPkgs =
        let
          pyProjectPath = localDepPath + "/pyproject.toml";
          pyProject = poetryLib.readTOML pyProjectPath;
        in
        if builtins.pathExists pyProjectPath then
          poetryLib.getBuildSystemPkgs
            {
              inherit pythonPackages pyProject;
            } else [ ];

      pname = normalizePackageName name;
      preferWheel' = preferWheel && pname != "wheel";
      fileInfo =
        let
          isBdist = f: lib.strings.hasSuffix "whl" f.file;
          isSdist = f: ! isBdist f && ! isEgg f;
          isEgg = f: lib.strings.hasSuffix ".egg" f.file;

          binaryDist = selectWheel fileCandidates;
          sourceDist = builtins.filter isSdist fileCandidates;

          eggs = builtins.filter isEgg fileCandidates;
          # the `wheel` package cannot be built from a wheel, since that requires the wheel package
          # this causes a circular dependency so we special-case ignore its `preferWheel` attribute value
          entries = (if preferWheel' then binaryDist ++ sourceDist else sourceDist ++ binaryDist) ++ eggs;
          lockFileEntry =
            if lib.length entries > 0 then builtins.head entries
            else throw "Missing suitable source/wheel file entry for ${name}"
          ;
          _isEgg = isEgg lockFileEntry;
        in
        rec {
          inherit (lockFileEntry) file hash;
          name = file;
          format =
            if _isEgg then "egg"
            else if lib.strings.hasSuffix ".whl" name then "wheel"
            else "pyproject";
        };

      format = if isWheelUrl then "wheel" else if isDirectory || isGit || isUrl then "pyproject" else fileInfo.format;

      hooks = python.pkgs.callPackage ./hooks { };
    in
    buildPythonPackage {
      inherit pname version;

      # Circumvent output separation (https://github.com/NixOS/nixpkgs/pull/190487)
      format = if format == "pyproject" then "poetry2nix" else format;

      doCheck = false; # We never get development deps

      # Stripping pre-built wheels lead to `ELF load command address/offset not properly aligned`
      dontStrip = format == "wheel";

      nativeBuildInputs = [
        hooks.poetry2nixFixupHook
      ]
      ++ lib.optional (!pythonPackages.isPy27) hooks.poetry2nixPythonRequiresPatchHook
      ++ lib.optional (isLocked && (getManyLinuxDeps fileInfo.name).str != null) autoPatchelfHook
      ++ lib.optionals (format == "wheel") [
        pythonPackages.wheelUnpackHook
        pythonPackages.pypaInstallHook
      ]
      ++ lib.optionals (format == "pyproject") [
        hooks.removePathDependenciesHook
        hooks.removeGitDependenciesHook
        hooks.removeWheelUrlDependenciesHook
        hooks.pipBuildHook
      ];

      buildInputs = lib.optional isLocked (getManyLinuxDeps fileInfo.name).pkg
        ++ lib.optional isDirectory buildSystemPkgs;

      propagatedBuildInputs =
        let
          deps = lib.filterAttrs
            (_: v: v)
            (
              lib.mapAttrs
                (
                  _: v:
                    let
                      constraints = v.python or "";
                      pep508Markers = v.markers or "";
                    in
                    (poetryLib.checkPythonVersions pyVersion constraints) && (if pep508Markers == "" then true else
                    (pyproject-nix.lib.pep508.evalMarkers
                      (pep508Env // {
                        extra = {
                          # All extras are always enabled
                          type = "extra";
                          value = lib.attrNames extras;
                        };
                      })
                      (pyproject-nix.lib.pep508.parseMarkers pep508Markers)))
                )
                dependencies
            );
          depAttrs = lib.attrNames deps;
        in
        builtins.map (n: pythonPackages.${normalizePackageName n}) depAttrs;

      inherit pos;

      meta = {
        broken = ! poetryLib.checkPythonVersions pyVersion python-versions;
        license = [ ];
        inherit (python.meta) platforms;
      };

      passthru = {
        inherit args;
        preferWheel = preferWheel';
      };

      # We need to retrieve kind from the interpreter and the filename of the package
      # Interpreters should declare what wheel types they're compatible with (python type + ABI)
      # Here we can then choose a file based on that info.
      src =
        let
          srcRoot =
            if isGit then
              (
                builtins.fetchGit ({
                  inherit (source) url;
                  rev = source.resolved_reference or source.reference;
                  ref = sourceSpec.branch or (if sourceSpec ? tag then "refs/tags/${sourceSpec.tag}" else "HEAD");
                } // (
                  lib.optionalAttrs
                    (((sourceSpec ? rev) || (sourceSpec ? branch) || (source ? resolved_reference) || (source ? reference))
                      && (lib.versionAtLeast builtins.nixVersion "2.4"))
                    {
                      allRefs = true;
                    }) // (
                  lib.optionalAttrs (lib.versionAtLeast builtins.nixVersion "2.4") {
                    submodules = true;
                  })
                )
              )
            else if isWheelUrl then
              builtins.fetchurl
                {
                  inherit (source) url;
                  sha256 = fileInfo.hash;
                }
            else if isUrl then
              builtins.fetchTarball
                {
                  inherit (source) url;
                  sha256 = fileInfo.hash;
                }
            else if isDirectory then
              (poetryLib.cleanPythonSources { src = localDepPath; })
            else if isFile then
              localDepPath
            else if isLegacy then
              pyproject-nix.fetchers.fetchFromLegacy
                {
                  pname = name;
                  inherit (fileInfo) file hash;
                  inherit (source) url;
                }
            else
              pyproject-nix.fetchers.fetchFromPypi {
                pname = name;
                inherit (fileInfo) file hash;
                inherit version;
              };
        in
        if source ? subdirectory then
          srcRoot + "/${source.subdirectory}"
        else
          srcRoot;
    }
  )
{ }
