{ pkgs
, lib
, stdenvNoCC
, pyproject-nix
}:
let
  inherit (builtins) substring elemAt;
  inherit (lib) toLower;

  inherit (pyproject-nix.lib.pypa) matchWheelFileName;
  inherit (pyproject-nix.lib.eggs) matchEggFileName;

  # Predict URL from the PyPI index.
  # Args:
  #   pname: package name
  #   file: filename including extension
  #   hash: SRI hash
  #   kind: Language implementation and version tag
  predictURLFromPypi =
    {
      # package name
      pname
    , # filename including extension
      file
    }:
    let
      matchedWheel = matchWheelFileName file;
      matchedEgg = matchEggFileName file;
      kind =
        if matchedWheel != null then "wheel"
        else if matchedEgg != null then elemAt matchedEgg 2
        else "source";
    in
    "https://files.pythonhosted.org/packages/${kind}/${toLower (substring 0 1 file)}/${pname}/${file}";
in
lib.mapAttrs (_: func: lib.makeOverridable func) {
  /*
    Fetch from the PyPI index.

    At first we try to fetch the predicated URL but if that fails we
    will use the Pypi API to determine the correct URL.

    Type: fetchFromPypi :: AttrSet -> derivation
    */
  fetchFromPypi =
    {
      # package name
      pname
    , # filename including extension
      file
    , # the version string of the dependency
      version
    , # SRI hash
      hash
    , # Options to pass to `curl`
      curlOpts ? ""
    ,
    }:
    let
      predictedURL = predictURLFromPypi { inherit pname file; };
    in
    stdenvNoCC.mkDerivation {
      name = file;
      nativeBuildInputs = [
        pkgs.curl
        pkgs.jq
      ];
      isWheel = lib.strings.hasSuffix "whl" file;
      system = "builtin";

      preferLocalBuild = true;
      impureEnvVars =
        lib.fetchers.proxyImpureEnvVars
        ++ [
          "NIX_CURL_FLAGS"
        ];

      inherit pname file version curlOpts predictedURL;

      builder = ./fetch-from-pypi.sh;

      outputHashMode = "flat";
      outputHashAlgo = "sha256";
      outputHash = hash;

      passthru = {
        urls = [ predictedURL ]; # retain compatibility with nixpkgs' fetchurl
      };
    };
}
