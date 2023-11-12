{ lib, pep600, pep656, ... }:
let
  inherit (builtins) concatStringsSep filter split match elemAt compareVersions length sort head;
  inherit (lib) isString toLower;
  inherit (lib.strings) hasPrefix toInt;

  matchWheelFileName = match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).whl";

  # PEP-625 only specifies .tar.gz as valid extension but .zip is also fairly widespread.
  matchSdistFileName = match "([^-]+)-(.+)(\.tar\.gz|\.zip)";

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

  checkTagVersion = sourceVersion: tagVersion: tagVersion == null || tagVersion == sourceVersion.major || (
    hasPrefix sourceVersion.major tagVersion && (
      (toInt (sourceVersion.major + sourceVersion.minor)) >= toInt tagVersion
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
       version = "37";
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
      version = optionalString (mAt 1);
    };

  /* Parse ABI tags.

     As described in https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#python-tag.

     Type: parseABITag :: string -> AttrSet

     Example:
     # parseABITag "cp37dmu"
     {
       rest = "dmu";
       implementation = "cp";
       version = "37";
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
      version = optionalString (mAt 1);
      rest = mAt 2;
    };

  /* Check whether string is a sdist file or not.

     Type: isSdistFileName :: string -> bool

     Example:
     # isSdistFileName "cryptography-41.0.1.tar.gz"
     true
  */
  isSdistFileName =
    # The filename string
    name: matchSdistFileName name != null;


  /* Regex match a wheel file name, returning a list of match groups. Returns null if no match.

     Type: matchWheelFileName :: string -> [ string ]
  */
  matchWheelFileName = name:
    let
      m = match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).whl" name;
    in
    if m != null then filter isString m else null;

  /* Regex match an egg file name, returning a list of match groups. Returns null if no match.

     Type: matchEggFileName :: string -> [ string ]
  */
  matchEggFileName = name:
    let
      m = match "([^-]+)-([^-]+)-(.+)\\.egg" name;
    in
    if m != null then filter isString m else null;

  /* Check whether string is a wheel file or not.

     Type: isWheelFileName :: string -> bool

     Example:
     # isWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     true
  */
  isWheelFileName =
    # The filename string
    name: matchWheelFileName name != null;

  /* Parse PEP-427 wheel file names.

     Type: parseFileName :: string -> AttrSet

     Example:
     # parseFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     {
      abiTag = {  # Parsed by pypa.parseABITag
        implementation = "abi";
        version = "3";
        rest = "";
      };
      buildTag = null;
      distribution = "cryptography";
      languageTags = [  # Parsed by pypa.parsePythonTag
        {
          implementation = "cpython";
          version = "37";
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
      # Keep filename around so selectWheel & such that returns structured filtered
      # data becomes more ergonomic to use
      filename = name;
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

     Type: isPlatformTagCompatible :: AttrSet -> derivation -> string -> bool

     Example:
     # isPlatformTagCompatible pkgs.python3 "manylinux2014_x86_64"
     true
  */
  isPlatformTagCompatible =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Libc derivation
    libc:
    # Python tag
    platformTag:
    if platformTag == "any" then true
    else if hasPrefix "manylinux" platformTag then pep600.manyLinuxTagCompatible platform libc platformTag
    else if hasPrefix "musllinux" platformTag then pep656.muslLinuxTagCompatible platform libc platformTag
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
     # isPythonTagCompatible pkgs.python3 (pypa.parsePythonTag "py3")
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
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Libc derivation
    libc:
    # Python interpreter derivation
    python:
    # The parsed wheel filename
    file:
    (
      self.isABITagCompatible python file.abiTag
      &&
      lib.any (self.isPythonTagCompatible python) file.languageTags
      &&
      lib.any (self.isPlatformTagCompatible platform libc) file.platformTags
    );

  /* Select compatible wheels from a list and return them in priority order.

     Type: selectWheels :: derivation -> [ AttrSet ] -> [ AttrSet ]

     Example:
     # selectWheels pkgs.python3 [ (pypa.parseWheelFileName "Pillow-9.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl") ]
     [ (pypa.parseWheelFileName "Pillow-9.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl") ]
  */
  selectWheels =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Python interpreter derivation
    python:
    # List of files as parsed by parseWheelFileName
    files:
    let
      # Get sorting/filter criteria fields
      withSortedTags = map
        (file:
          let
            abiCompatible = self.isABITagCompatible python file.abiTag;

            # Filter only compatible tags
            languageTags = filter (self.isPythonTagCompatible python) file.languageTags;
            # Extract the tag as a number. E.g. "37" is `toInt "37"` and "none"/"any" is 0
            languageTags' = map (tag: if tag == "none" then 0 else toInt tag.version) languageTags;

          in
          {
            bestLanguageTag = head (sort (x: y: x > y) languageTags');
            compatible = abiCompatible && length languageTags > 0 && lib.any (self.isPlatformTagCompatible platform python.stdenv.cc.libc) file.platformTags;
            inherit file;
          })
        files;

      # Only consider files compatible with this interpreter
      compatibleFiles = filter (file: file.compatible) withSortedTags;

      # Sort files based on their tags
      sorted = sort
        (
          x: y:
            x.file.distribution > y.file.distribution
            || x.file.version > y.file.version
            || (x.file.buildTag != null && (y.file.buildTag == null || x.file.buildTag > y.file.buildTag))
            || x.bestLanguageTag > y.bestLanguageTag
        )
        compatibleFiles;

    in
    # Strip away temporary sorting metadata
    map (file': file'.file) sorted
  ;

})
