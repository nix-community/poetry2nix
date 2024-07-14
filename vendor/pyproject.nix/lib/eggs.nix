{ lib, ... }:
let
  inherit (builtins) filter match elemAt compareVersions sort;
  inherit (lib) isString;

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

in
lib.fix (self: {
  /* Regex match an egg file name, returning a list of match groups. Returns null if no match.

     Type: matchEggFileName :: string -> [ string ]
  */
  matchEggFileName = name:
    let
      m = match "([^-]+)-([^-]+)-(.+)\\.egg" name;
    in
    if m != null then filter isString m else null;

  /* Check whether string is an egg file or not.

     Type: isEggFileName :: string -> bool

     Example:
     # isEggFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     false
  */
  isEggFileName =
    # The filename string
    name: self.matchEggFileName name != null;

  /* Parse an egg file name.

     Type: parsehEggFileName :: string -> AttrSet

     Example:
     # parseEggFileName
  */
  parseEggFileName = name:
    let
      m = self.matchEggFileName name;
      mAt = elemAt m;
      langM = match "([^0-9]*)(.+)" (mAt 2);
      langAt = elemAt langM;
    in
    assert m != null; {
      filename = name;
      distribution = mAt 0;
      version = mAt 1;
      languageTag = {
        implementation = normalizeImpl (langAt 0);
        version = langAt 1;
      };
    };

  /* Select compatible eggs from a list and return them in priority order.

     Type: selectEggs :: derivation -> [ AttrSet ] -> [ AttrSet ]
  */
  selectEggs =
    # Python interpreter derivation
    python:
    # List of files parsed by parseEggFileName
    files:
    let
      inherit (python.passthru) pythonVersion implementation;

      langCompatible = filter
        (file: file.languageTag.implementation == "python" || file.languageTag.implementation == implementation)
        files;

      versionCompatible = filter
        (file: compareVersions pythonVersion file.languageTag.version >= 0)
        langCompatible;

    in
    sort (a: b: compareVersions a.languageTag.version b.languageTag.version > 0) versionCompatible;
})
