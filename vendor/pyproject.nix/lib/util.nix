{
  pep440,
  lib,
  ...
}:
let
  inherit (builtins) all attrNames concatMap;
  inherit (lib) hasSuffix;
in
{
  /**
    Filter Python interpreter derivations from an attribute set based on
    python-requires constraints.

    # Example:
    ```nix
    util.filterPythonInterpreters {
      requires = pep440.parseVersionConds ">=3.12";
      inherit (pkgs) pythonInterpreters;
    }
    ->
    [
      «derivation /nix/store/5iwwrbr1dh1yc63gmz1alsk1d96jgfjy-python3-3.12.11.drv»
      «derivation /nix/store/6p8y1zwm68kksdrad12ybn7lrvvpgwc5-python3-3.13.8.drv»
      «derivation /nix/store/fvac8j3h7sxqfaw7hllr9cllns34pgcm-python3-3.14.0.drv»
    ]
    ```
  */

  filterPythonInterpreters =
    {
      requires-python,
      pythonInterpreters,
      pre ? false,
      implementation ? "cpython",
    }:
    concatMap (
      name:
      let
        drv = pythonInterpreters.${name};
        version = pep440.parseVersion drv.version;
        pythonVersion = pep440.parseVersion drv.pythonVersion;
      in
      if
        (
          name != "override"
          && name != "overrideDerivation"
          &&
            # Filter prebuilt pypy derivations & python3Minimal
            !(hasSuffix "prebuilt" name || hasSuffix "Minimal" name)
          && (drv.implementation or "") == implementation
          && (pre || version.pre == null)
          && all (cond: pep440.comparators.${cond.op} pythonVersion cond.version) requires-python
        )
      then
        [ drv ]
      else
        [ ]
    ) (attrNames pythonInterpreters);
}
