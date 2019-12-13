{ lib, stdenv, python, isLinux ? stdenv.isLinux }:

let
  inherit (lib.strings) hasSuffix hasInfix splitString removeSuffix;

  # The 'cpxy" as determined by `python.version`
  #
  # e.g "2.7.17" -> "cp27"
  #     "3.5.9"  -> "cp35"
  pythonTag =
    let
      ver = builtins.splitVersion python.version;
      major = builtins.elemAt ver 0;
      minor = builtins.elemAt ver 1;
    in
      "cp${major}${minor}";

  abiTag = "${pythonTag}m";

  #
  # Parses wheel file returning an attribute set
  #
  toWheelAttrs = str:
    let
      entries = splitString "-" str;
      p = removeSuffix ".whl" (builtins.elemAt entries 4);
    in
      {
        pkgName = builtins.elemAt entries 0;
        pkgVer = builtins.elemAt entries 1;
        pyVer = builtins.elemAt entries 2;
        abi = builtins.elemAt entries 3;
        platform = p;
      };

  #
  # Renders a wheel attribute set into a string
  #
  # e.g (toFile (toWheelAttrs x)) == x
  toFileName = x: "${x.pkgName}-${x.pkgVer}-${x.pyVer}-${x.abi}-${x.platform}.whl";

  #
  # Builds list of acceptable osx wheel files
  #
  # <versions>   accepted versions in descending order of preference
  # <candidates> list of wheel files to select from
  findBestMatches = versions: candidates:
    let
      v = lib.lists.head versions;
      vs = lib.lists.tail versions;
    in
      if (builtins.length versions == 0)
      then []
      else (builtins.filter (x: hasInfix v x.file) candidates) ++ (findBestMatches vs candidates);


  #
  # Selects the best matching wheel file from a list of files
  #
  selectWheel = files:
    let
      filesWithoutSources = (builtins.filter (x: hasSuffix ".whl" x.file) files);

      withPython = pyver: abi: x: x.pyVer == pyver && x.abi == abi;

      withPlatform = if isLinux
      then (
        x: x.platform == "manylinux1_${stdenv.platform.kernelArch}"
        || x.platform == "manylinux2010_${stdenv.platform.kernelArch}"
        || x.platform == "manylinux2014_${stdenv.platform.kernelArch}"
      )
      else (x: hasInfix "macosx" x.platform);

      filterWheel = x:
        let
          f = toWheelAttrs x.file;
        in
          (withPython pythonTag abiTag f) && (withPlatform f);

      filtered = builtins.filter filterWheel filesWithoutSources;

      choose = files:
        let
          osxMatches = [ "10_12" "10_11" "10_10" "10_9" ];
          linuxMatches = [ "manylinux1_" "manylinux2010_" "manylinux2014_" ];
          chooseLinux = x: lib.singleton (builtins.head (findBestMatches linuxMatches x));
          chooseOSX = x: lib.singleton (builtins.head (findBestMatches osxMatches x));
        in
          if isLinux
          then chooseLinux files
          else chooseOSX files;

    in
      if (builtins.length filtered == 0)
      then []
      else choose (filtered);

in
{
  inherit selectWheel;
}
