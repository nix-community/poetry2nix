{ lib, pep600, pep656, ... }:
let
  inherit (builtins) concatStringsSep filter split match elemAt compareVersions;
  inherit (lib) isString toLower;
  inherit (lib.strings) hasPrefix;

  matchWheelFileName = match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).whl";

  # Tag normalization documented in
  # https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#details
  normalizedImpls = {
    py = "python";
    cp = "cpython";
    ip = "ironpython";
    pp = "pypy";
    jy = "jython";
  };
  normalizeImpl = t: normalizedImpls.${t} or t;

  optionalString = s: if s != "" then s else null;

  parseTagVersion = v:
    let
      m = match "([0-9])([0-9]*)" v;
      mAt = elemAt m;
    in
    if v == "" then null else assert m != null; {
      major = mAt 0;
      minor = optionalString (mAt 1);
    };

  checkTagVersion = sourceVersion: tagVersion: tagVersion == null || (
    tagVersion.major == sourceVersion.major && (
      tagVersion.minor == null || (
        (compareVersions sourceVersion.minor tagVersion.minor) >= 0
      )
    )
  );


in
lib.fix (self: {
  /* Normalize package name as documented in https://packaging.python.org/en/latest/specifications/name-normalization/#normalization

     Type: normalizePackageName :: string -> string

     Example:
       # readPyproject "Friendly-Bard"
       "friendly-bard"
  */
  normalizePackageName =
    let
      concatDash = concatStringsSep "-";
      splitSep = split "[-_\.]+";
    in
    name: toLower (concatDash (filter isString (splitSep name)));

  /* Parse Python tags.

     As described in https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#python-tag.

     Type: parsePythonTag :: string -> AttrSet

     Example:
     # parsePythonTag "cp37"
     {
       implementation = "cpython";
       version = {
         major = "3";
         minor = "7";
       };
     }
     */
  parsePythonTag =
    tag:
    let
      m = match "([a-z]+)([0-9]*)" tag;
      mAt = elemAt m;
    in
    assert m != null; {
      implementation = normalizeImpl (mAt 0);
      version = parseTagVersion (mAt 1);
    };

  /* Parse ABI tags.

     As described in https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#python-tag.

     Type: parseABITag :: string -> AttrSet

     Example:
     # parseABITag "cp37dmu"
     {
       rest = "dmu";
       implementation = "cp";
       version = {
         major = "3";
         minor = "7";
       };
     }
  */
  parseABITag =
    tag:
    let
      m = match "([a-z]+)([0-9]*)_?([a-z0-9]*)" tag;
      mAt = elemAt m;
    in
    assert m != null; {
      implementation = normalizeImpl (mAt 0);
      version = parseTagVersion (mAt 1);
      rest = mAt 2;
    };

  /* Check whether string is a wheel file or not.

     Type: isWheelFileName :: string -> bool

     Example:
     # isWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     true
  */
  isWheelFileName = name: matchWheelFileName name != null;

  /* Parse PEP-427 wheel file names.

     Type: parseFileName :: string -> AttrSet

     Example:
     # parseFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     {
      abiTag = {  # Parsed by pypa.parseABITag
        implementation = "abi";
        version = {
          major = "3";
          minor = null;
        };
        flags = [ ];
      };
      buildTag = null;
      distribution = "cryptography";
      languageTags = [  # Parsed by pypa.parsePythonTag
        {
          implementation = "cpython";
          version = {
            major = "3";
            minor = "7";
          };
        }
      ];
      platformTags = [ "manylinux_2_17_aarch64" "manylinux2014_aarch64" ];
      version = "41.0.1";
    }
  */
  parseWheelFileName =
    # The wheel filename is `{distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl`.
    name:
    let
      m = matchWheelFileName name;
      mAt = elemAt m;
    in
    assert m != null; {
      distribution = mAt 0;
      version = mAt 1;
      buildTag = mAt 3;
      languageTags = map self.parsePythonTag (filter isString (split "\\." (mAt 4)));
      abiTag = self.parseABITag (mAt 5);
      platformTags = filter isString (split "\\." (mAt 6));
    };

  /* Check whether an ABI tag is compatible with this python interpreter.

     Type: isABITagCompatible :: derivation -> string -> bool

     Example:
     # isABITagCompatible pkgs.python3 (pypa.parseABITag "cp37")
     true
  */
  isABITagCompatible =
    # Python interpreter derivation
    python:
    # ABI tag string
    abiTag:
    let
      inherit (python.passthru) sourceVersion implementation;
    in
    (
      # None is a wildcard compatible with any implementation
      (abiTag.implementation == "none" || abiTag.implementation == "any")
      ||
      # implementation == sys.implementation.name
      abiTag.implementation == implementation
      ||
      # The CPython stable ABI is abi3 as in the shared library suffix.
      (abiTag.implementation == "abi" && implementation == "cpython")
    )
    &&
    # Check version
    (
      checkTagVersion sourceVersion abiTag.version
    );

  /* Check whether a platform tag is compatible with this python interpreter.

     Type: isPlatformTagCompatible :: derivation -> string -> bool

     Example:
     # isPlatformTagCompatible pkgs.python3 "manylinux2014_x86_64"
     true
  */
  isPlatformTagCompatible =
    # Python interpreter derivation
    python:
    # Python tag
    platformTag:
    let
      platform = python.stdenv.targetPlatform;
    in
    if platformTag == "any" then true
    else if hasPrefix "manylinux" platformTag then pep600.manyLinuxTagCompatible python.stdenv platformTag
    else if hasPrefix "musllinux" platformTag then pep656.muslLinuxTagCompatible python.stdenv platformTag
    else if hasPrefix "macosx" platformTag then
      (
        let
          m = match "macosx_([0-9]+)_([0-9]+)_(.+)" platformTag;
          mAt = elemAt m;
          major = mAt 0;
          minor = mAt 1;
          arch = mAt 2;
        in
        assert m != null; (
          platform.isDarwin
          &&
          ((arch == "universal2" && (platform.darwinArch == "arm64" || platform.darwinArch == "x86_64")) || arch == platform.darwinArch)
          &&
          compareVersions platform.darwinSdkVersion "${major}.${minor}" >= 0
        )
      )
    else if platformTag == "win32" then (platform.isWindows && platform.is32Bit && platform.isx86)
    else if hasPrefix "win_" platformTag then
      (
        let
          m = match "win_(.+)" platformTag;
          arch = elemAt m 0;
        in
        assert m != null;
        platform.isWindows && (
          # Note that these platform mappings are incomplete.
          # Nixpkgs should gain windows platform tags so we don't have to map them manually here.
          if arch == "amd64" then platform.isx86_64
          else if arch == "arm64" then platform.isAarch64
          else false
        )
      )
    else if hasPrefix "linux" platformTag then
      (
        let
          m = match "linux_(.+)" platformTag;
          arch = elemAt m 0;
        in
        assert m != null;
        platform.isLinux && arch == platform.linuxArch
      )
    else throw "Unknown platform tag: '${platformTag}'";

  /* Check whether a Python language tag is compatible with this Python interpreter.

     Type: isPythonTagCompatible :: derivation -> AttrSet -> bool

     Example:
     # isPlatformTagCompatible pkgs.python3 (pypa.parsePythonTag "py3")
     true
  */
  isPythonTagCompatible =
    # Python interpreter derivation
    python:
    # Python tag
    pythonTag:
    let
      inherit (python.passthru) sourceVersion implementation;
    in
    (
      # Python is a wildcard compatible with any implementation
      pythonTag.implementation == "python"
      ||
      # implementation == sys.implementation.name
      pythonTag.implementation == implementation
    )
    &&
    # Check version
    checkTagVersion sourceVersion pythonTag.version
  ;

  /* Check whether wheel file name is compatible with this python interpreter.

     Type: isWheelFileCompatible :: derivation -> AttrSet -> bool

     Example:
     # isWheelFileCompatible pkgs.python3 (pypa.parseWheelFileName "Pillow-9.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl")
     true
  */
  isWheelFileCompatible =
    # Python interpreter derivation
    python:
    # The parsed wheel filename
    file:
    (
      self.isABITagCompatible python file.abiTag
      &&
      lib.any (self.isPythonTagCompatible python) file.languageTags
      &&
      lib.any (self.isPlatformTagCompatible python) file.platformTags
    );
})
