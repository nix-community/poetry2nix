_:

let
  inherit (builtins) match elemAt split filter isString;
  matchFileName = match "([^-]+)-([^-]+)(-([[:digit:]][^-]*))?-([^-]+)-([^-]+)-(.+).whl";

in
{
  /* Check whether string is a wheel file or not.

     Type: isWheelFileName :: string -> bool

     Example:
     # isWheelFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     true
  */
  isWheelFileName = name: matchFileName name != null;

  /* Parse PEP-427 wheel file names.

     Type: parseFileName :: string -> AttrSet

     Example:
     # parseFileName "cryptography-41.0.1-cp37-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl"
     {
      abiTag = "abi3";
      buildTag = null;
      distribution = "cryptography";
      languageTag = "cp37";
      platformTags = [ "manylinux_2_17_aarch64" "manylinux2014_aarch64" ];
      version = "41.0.1";
    }
  */
  parseFileName =
    # The wheel filename is `{distribution}-{version}(-{build tag})?-{python tag}-{abi tag}-{platform tag}.whl`.
    name:
    let
      m = matchFileName name;
      mAt = elemAt m;
    in
    assert m != null; {
      distribution = mAt 0;
      version = mAt 1;
      buildTag = mAt 3;
      languageTag = mAt 4;
      abiTag = mAt 5;
      platformTags = filter isString (split "\\." (mAt 6));
    };
}
