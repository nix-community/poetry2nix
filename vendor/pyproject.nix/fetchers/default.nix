{ pkgs
, lib
,
}:
let
  inherit (builtins) substring filter head nixPath;
  inherit (lib) toLower;

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
    , # Language implementation and version tag
      kind
    ,
    }: "https://files.pythonhosted.org/packages/${kind}/${toLower (substring 0 1 file)}/${pname}/${file}";
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
    , # Language implementation and version tag
      kind
    , # Options to pass to `curl`
      curlOpts ? ""
    ,
    }:
    let
      predictedURL = predictURLFromPypi { inherit pname file kind; };
    in
    pkgs.stdenvNoCC.mkDerivation {
      name = file;
      nativeBuildInputs = [
        pkgs.buildPackages.curl
        pkgs.buildPackages.jq
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

  /*
    Fetch from the PyPI legacy API.

    Some repositories (such as Devpi) expose the Pypi legacy API (https://warehouse.pypa.io/api-reference/legacy.html).

    Type: fetchFromLegacy :: AttrSet -> derivation
    */
  fetchFromLegacy =
    {
      # package name
      pname
    , # URL to package index
      url
    , # filename including extension
      file
    , # SRI hash
      hash
    ,
    }:
    let
      pathParts = filter ({ prefix, path }: "NETRC" == prefix) nixPath; # deadnix: skip
      netrc_file =
        if (pathParts != [ ])
        then (head pathParts).path
        else "";
    in
    pkgs.runCommand file
      {
        nativeBuildInputs = [ pkgs.buildPackages.python3 ];
        impureEnvVars = lib.fetchers.proxyImpureEnvVars;
        outputHashMode = "flat";
        outputHashAlgo = "sha256";
        outputHash = hash;
        NETRC = netrc_file;
        passthru.isWheel = lib.strings.hasSuffix "whl" file;
      } ''
      python ${./fetch-from-legacy.py} ${url} ${pname} ${file}
      mv ${file} $out
    '';
}
