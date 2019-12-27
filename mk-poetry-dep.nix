{ autoPatchelfHook
, pkgs
, lib
, python
, buildPythonPackage
, pythonPackages
, poetryLib
}:
{ name
, version
, files
, source
, dependencies ? {}
, python-versions
, supportedExtensions ? lib.importJSON ./extensions.json
, ...
}: let

  inherit (poetryLib) isCompatible getManyLinuxDeps fetchFromPypi;

  inherit (import ./pep425.nix {
    inherit lib python;
    inherit (pkgs) stdenv;
  }) selectWheel
    ;

  fileCandidates = let
    supportedRegex = ("^.*?(" + builtins.concatStringsSep "|" supportedExtensions + ")");
    matchesVersion = fname: builtins.match ("^.*" + builtins.replaceStrings [ "." ] [ "\\." ] version + ".*$") fname != null;
    hasSupportedExtension = fname: builtins.match supportedRegex fname != null;
  in
    builtins.filter (f: matchesVersion f.file && hasSupportedExtension f.file) files;

  isGit = source != null && source.type == "git";

  fileInfo = let
    isBdist = f: lib.strings.hasSuffix "whl" f.file;
    isSdist = f: ! isBdist f;
    binaryDist = selectWheel fileCandidates;
    sourceDist = builtins.filter isSdist fileCandidates;
    lockFileEntry = if (builtins.length sourceDist) > 0 then builtins.head sourceDist else builtins.head binaryDist;
  in
    rec {
      inherit (lockFileEntry) file hash;
      name = file;
      format = if lib.strings.hasSuffix ".whl" name then "wheel" else "setuptools";
      kind = if format == "setuptools" then "source" else (builtins.elemAt (lib.strings.splitString "-" name) 2);
    };

in
buildPythonPackage {
  pname = name;
  version = version;

  doCheck = false; # We never get development deps
  dontStrip = true;
  format = if isGit then "setuptools" else fileInfo.format;

  nativeBuildInputs = if (!isGit && (getManyLinuxDeps fileInfo.name).str != null) then [ autoPatchelfHook ] else [];
  buildInputs = if !isGit then (getManyLinuxDeps fileInfo.name).pkg else [];

  propagatedBuildInputs =
    let
      # Some dependencies like django gets the attribute name django
      # but dependencies try to access Django
      deps = builtins.map (d: lib.toLower d) (builtins.attrNames dependencies);
    in
      builtins.map (n: pythonPackages.${n}) deps;

  meta = {
    broken = ! isCompatible python.version python-versions;
    license = [];
  };

  # We need to retrieve kind from the interpreter and the filename of the package
  # Interpreters should declare what wheel types they're compatible with (python type + ABI)
  # Here we can then choose a file based on that info.
  src = if isGit then (
    builtins.fetchGit {
      inherit (source) url;
      rev = source.reference;
    }
  ) else fetchFromPypi {
    pname = name;
    inherit (fileInfo) file hash kind;
  };
}
