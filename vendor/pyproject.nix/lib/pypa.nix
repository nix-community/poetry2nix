{
  lib,
  pep600,
  pep656,
  ...
}:
let
  inherit (builtins)
    concatStringsSep
    filter
    split
    match
    elemAt
    compareVersions
    length
    sort
    head
    elem
    any
    ;
  inherit (lib)
    isString
    toLower
    concatStrings
    take
    splitString
    ;
  inherit (lib.strings) hasPrefix toInt;

  matchWheelFileName = match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).whl";

  # PEP-625 only specifies .tar.gz as valid extension but .zip is also fairly widespread.
  matchSdistFileName = match "([^-]+)-(.+)(\.tar\.gz|\.zip)";

  matchMacosTag = match "macosx_([0-9]+)_([0-9]+)_(.+)";

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

in
lib.fix (self: {
  /**
    Normalize package name as documented in https://packaging.python.org/en/latest/specifications/name-normalization/#normalization

    # Type:
    `string -> string`

    # Example
    ```nix
    readPyproject "Friendly-Bard"
    ->
    "friendly-bard"
    ```
  */
  normalizePackageName =
    let
      concatDash = concatStringsSep "-";
      splitSep = split "[-_\.]+";
    in
    name: toLower (concatDash (filter isString (splitSep name)));

  /**
    Parse Python tags.

    As described in https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#python-tag.

    Type: parsePythonTag :: string -> AttrSet

    # Example
    ```nix
    parsePythonTag "cp37"
    ->
    {
      implementation = "cpython";
      version = "37";
    }
    ```
  */
  parsePythonTag =
    tag:
    let
      m = match "([a-z]+)([0-9]*)" tag;
    in
    assert m != null;
    {
      implementation = normalizeImpl (elemAt m 0);
      version = optionalString (elemAt m 1);
    };

  /**
    Parse ABI tags.

    As described in https://packaging.python.org/en/latest/specifications/platform-compatibility-tags/#python-tag.

    # Type
    `string -> AttrSet`
    ```
  */
  parseABITag = tag: tag; # Verbatim tag

  /**
    Check whether string is a sdist file or not.

    # Type
    `string -> bool`

    # Example:
    ```nix
    isSdistFileName "cryptography-41.0.1.tar.gz"
    ->
    true
    ```
  */
  isSdistFileName =
    # The filename string
    name: matchSdistFileName name != null;

  /**
    Regex match a wheel file name, returning a list of match groups. Returns null if no match.

    # Type
    `string -> [ string ]`
  */
  matchWheelFileName =
    name:
    let
      m = match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).whl" name;
    in
    if m != null then filter isString m else null;

  /**
    Check whether string is a wheel file or not.

    # Type
    `string -> bool`

    # Example:
    ```
    isWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
    ->
    true
    ```
  */
  isWheelFileName =
    # The filename string
    name: matchWheelFileName name != null;

  /**
    Parse PEP-427 wheel file names.

     # Type
     `string -> AttrSet`

     # Example:
     ```nix
     parseFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     ->
     {
      abiTags = [ "abi3" ];
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
    ```
  */
  parseWheelFileName =
    # The wheel filename is `{distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl`.
    name:
    let
      m = matchWheelFileName name;
    in
    assert m != null;
    {
      distribution = elemAt m 0;
      version = elemAt m 1;
      buildTag = elemAt m 3;
      languageTags = map self.parsePythonTag (filter isString (split "\\." (elemAt m 4)));
      abiTags = filter isString (split "\\." (elemAt m 5));
      platformTags = filter isString (split "\\." (elemAt m 6));
      # Keep filename around so selectWheel & such that returns structured filtered
      # data becomes more ergonomic to use
      filename = name;
    };

  /**
    Check whether an ABI tag is compatible with this python interpreter.

    # Type
    `derivation -> string -> bool`

    # Example:
    ```nix
    isABITagCompatible pkgs.python3 (pypa.parseABITag "cp37")
    ->
    true
    ```
  */
  isABITagCompatible =
    # Python interpreter derivation
    python:
    let
      abiTags =
        python.passthru.pythonABITags or (
          # Fall back to computing an ABI tag.
          #
          # This isn't strictly correct in the face of things like Python free-threading
          # which has a `t` suffix but there is no way right now to introspect & check
          # if the GIL is enabled or not.
          #
          # So a free-threaded build will erroneously be returned as compatible with
          # regular CPython wheels.
          let
            inherit (python.passthru) sourceVersion implementation pythonVersion;
          in
          if implementation == "cpython" then
            [
              "none"
              "any"
              "abi3"
              "cp${sourceVersion.major}${sourceVersion.minor}"
            ]
          else if implementation == "pypy" then
            [
              "none"
              "any"
              "pypy${concatStrings (take 2 (splitString "." pythonVersion))}_pp${sourceVersion.major}${sourceVersion.minor}"
            ]
          else
            [
              "none"
              "any"
            ]
        );
    in
    tag: elem tag abiTags;

  /**
    Check whether a platform tag is compatible with this python interpreter.

    # Type
    `AttrSet -> derivation -> string -> bool`

    # Example:
    ```nix
    isPlatformTagCompatible pkgs.python3 "manylinux2014_x86_64"
    ->
    true
    ```
  */
  isPlatformTagCompatible =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Libc derivation
    libc:
    # Python tag
    platformTag:
    if platformTag == "any" then
      true
    else if hasPrefix "manylinux" platformTag then
      pep600.manyLinuxTagCompatible platform libc platformTag
    else if hasPrefix "musllinux" platformTag then
      pep656.muslLinuxTagCompatible platform libc platformTag
    else if hasPrefix "macosx" platformTag then
      (
        let
          m = matchMacosTag platformTag;
          major = elemAt m 0;
          minor = elemAt m 1;
          arch = elemAt m 2;
        in
        assert m != null;
        (
          platform.isDarwin
          && (
            (arch == "universal2" && (platform.darwinArch == "arm64" || platform.darwinArch == "x86_64"))
            || arch == platform.darwinArch
          )
          && compareVersions platform.darwinSdkVersion "${major}.${minor}" >= 0
        )
      )
    else if platformTag == "win32" then
      (platform.isWindows && platform.is32bit && platform.isx86_32)
    else if hasPrefix "win_" platformTag then
      (
        let
          m = match "win_(.+)" platformTag;
          arch = elemAt m 0;
        in
        assert m != null;
        platform.isWindows
        && (
          # Note that these platform mappings are incomplete.
          # Nixpkgs should gain windows platform tags so we don't have to map them manually here.
          if arch == "amd64" then
            platform.isx86_64
          else if arch == "arm64" then
            platform.isAarch64
          else
            false
        )
      )
    else if hasPrefix "linux" platformTag then
      (
        let
          m = match "linux_(.+)" platformTag;
          arch = elemAt m 0;

          linuxArch = if platform.linuxArch == "arm64" then "aarch64" else platform.linuxArch;
        in
        assert m != null;
        platform.isLinux && arch == linuxArch
      )
    else if hasPrefix "ios" platformTag then
      # e.g., ios_13_0_arm64_iphoneos
      let
        m = match "ios_([0-9]+)_([0-9]+)_(.+)_.+" platformTag;
        major = elemAt m 0;
        minor = elemAt m 0;
        arch = elemAt m 2;
      in
      assert m != null;
      platform.isiOS
      && arch == platform.darwinArch
      && compareVersions platform.darwinSdkVersion "${major}.${minor}" >= 0
    else if hasPrefix "android" platformTag then
      # e.g., android_32_arm64_v8a
      let
        m = match "android_([0-9])+_(.+)" platformTag;
        apiLevel = elemAt m 0;
        abi = elemAt m 1;
      in
      assert m != null;
      platform.isAndroid
      &&
        (
          if abi == "armeabi_v7a" then
            "arm"
          else if abi == "arm64_v8a" then
            "arm64"
          else if abi == "x86" then
            "x86"
          else if abi == "x86_64" then
            "x86_64"
          else
            throw "Unhandled Android ABI: ${abi}"
        ) == platform.linuxArch
      && compareVersions platform.androidSdkVersion apiLevel >= 0
    else
      false;

  /**
    Check whether a Python language tag is compatible with this Python interpreter.

    # Type
    `derivation -> AttrSet -> bool`

    # Example:
    ```nix
    isPythonTagCompatible pkgs.python3 (pypa.parsePythonTag "py3")
    ->
    true
    ```
  */
  isPythonTagCompatible =
    # Python interpreter derivation
    python:
    let
      #   inherit (python.passthru) sourceVersion implementation;
      # in
      inherit (python.passthru) implementation pythonVersion;

      version' = splitString "." pythonVersion;
      major = elemAt version' 0;
      minor = elemAt version' 1;
    in
    assert length version' >= 2;
    # Python tag
    pythonTag:
    (
      # Python is a wildcard compatible with any implementation
      pythonTag.implementation == "python"
      ||
        # implementation == sys.implementation.name
        pythonTag.implementation == implementation
    )
    &&
      # Check version
      (
        pythonTag.version == null
        || pythonTag.version == major
        || (hasPrefix major pythonTag.version && ((toInt (major + minor)) >= toInt pythonTag.version))
      );

  /**
    Check whether wheel file name is compatible with this python interpreter.

    # Type
    `derivation -> AttrSet -> bool`

    # Example:
    ```nix
    isWheelFileCompatible pkgs.python3 (pypa.parseWheelFileName "Pillow-9.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl")
    ->
    true
    ```
  */
  isWheelFileCompatible =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Libc derivation
    libc:
    # Python interpreter derivation
    python:
    let
      isABITagCompatible = self.isABITagCompatible python;
    in
    # The parsed wheel filename
    file:
    (
      any isABITagCompatible file.abiTags
      && any (self.isPythonTagCompatible python) file.languageTags
      && any (self.isPlatformTagCompatible platform libc) file.platformTags
    );

  /**
    Select compatible wheels from a list and return them in priority order.

    # Type
    `AttrSet -> derivation -> [ AttrSet ] -> [ AttrSet ]`

    # Example:
    ```nix
    selectWheels (lib.systems.elaborate "x86_64-linux") [ (pypa.parseWheelFileName "Pillow-9.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl") ]
    ->
    [ (pypa.parseWheelFileName "Pillow-9.0.1-cp310-cp310-manylinux_2_17_x86_64.manylinux2014_x86_64.whl") ]
    ```
  */
  selectWheels =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Python interpreter derivation
    python:
    # List of files as parsed by parseWheelFileName
    files:
    if !lib.isAttrs platform then
      throw ''
        SelectWheel was called with wrong type for its first argument 'platform'.
        Pass only elaborated platforms.
        Example:
          `lib.systems.elaborate "x86_64-linux"`
      ''
    else
      let
        isABITagCompatible = self.isABITagCompatible python;
        isPythonTagCompatible = self.isPythonTagCompatible python;

        # Get sorting/filter criteria fields
        withSortedTags = map (
          file:
          let
            abiCompatible = any isABITagCompatible file.abiTags;

            # Filter only compatible tags
            languageTags = filter isPythonTagCompatible file.languageTags;
            # Extract the tag as a number. E.g. "37" is `toInt "37"` and "none"/"any" is 0
            languageTags' = map (tag: if tag == "none" then 0 else toInt tag.version) languageTags;
          in
          {
            bestLanguageTag = head (sort (x: y: x > y) languageTags');
            compatible =
              abiCompatible
              && length languageTags > 0
              && lib.any (self.isPlatformTagCompatible platform python.stdenv.cc.libc) file.platformTags;
            inherit file;
            # Prefer macOS wheels with specific architectures over universal2
            macArchPreference =
              let
                macArchs = filter isString (
                  map (
                    tag:
                    let
                      m = matchMacosTag tag;
                    in
                    if m != null then elemAt m 2 else null
                  ) file.platformTags
                );
              in
              if any (arch: arch != "universal2") macArchs then 1 else 0;
          }
        ) files;

        # Only consider files compatible with this interpreter
        compatibleFiles = filter (file: file.compatible) withSortedTags;

        # Sort files based on their tags
        sorted = sort (
          x: y:
          x.file.distribution > y.file.distribution
          || x.file.version > y.file.version
          || (x.file.buildTag != null && (y.file.buildTag == null || x.file.buildTag > y.file.buildTag))
          || x.bestLanguageTag > y.bestLanguageTag
          || x.macArchPreference > y.macArchPreference
        ) compatibleFiles;

      in
      # Strip away temporary sorting metadata
      map (file': file'.file) sorted;

})
