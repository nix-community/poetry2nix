{ pep599, ... }:
let
  inherit (builtins) match elemAt compareVersions splitVersion;

in

{
  /* Check if a musllinux tag is compatible with a given stdenv.

     Type: muslLinuxTagCompatible :: AttrSet -> string -> bool

     Example:
     # muslLinuxTagCompatible pkgs.stdenv "musllinux_1_1_x86_64"
     true
  */
  muslLinuxTagCompatible = stdenv: tag:
    let
      m = match "musllinux_([0-9]+)_([0-9]+)_(.*)" tag;
      mAt = elemAt m;
      tagMajor = mAt 0;
      tagMinor = mAt 1;
      tagArch = mAt 2;
      sysVersion' = elemAt (splitVersion stdenv.cc.libc.version);
      sysMajor = sysVersion' 0;
      sysMinor = sysVersion' 1;
    in
    if m == null then throw "'${tag}' is not a valid musllinux tag."
    else if stdenv.cc.libc.pname != "musl" then false
    else if compareVersions "${sysMajor}.${sysMinor}" "${tagMajor}.${tagMinor}" < 0 then false
    else if pep599.manyLinuxTargetMachines.${tagArch} != stdenv.targetPlatform.parsed.cpu.name then false
    else true;

}
