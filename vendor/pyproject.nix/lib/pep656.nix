{ pep599, ... }:
let
  inherit (builtins) match elemAt compareVersions splitVersion;

in

{
  /* Check if a musllinux tag is compatible with a given stdenv.

     Type: muslLinuxTagCompatible :: AttrSet -> derivation -> string -> bool

     Example:
     # muslLinuxTagCompatible pkgs.stdenv.targetPlatform pkgs.stdenv.cc.libc "musllinux_1_1_x86_64"
     true
  */
  muslLinuxTagCompatible =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Libc derivation
    libc:
    # Platform tag string
    tag:
    let
      m = match "musllinux_([0-9]+)_([0-9]+)_(.*)" tag;
      mAt = elemAt m;
      tagMajor = mAt 0;
      tagMinor = mAt 1;
      tagArch = mAt 2;
      sysVersion' = elemAt (splitVersion libc.version);
      sysMajor = sysVersion' 0;
      sysMinor = sysVersion' 1;
    in
    if m == null then throw "'${tag}' is not a valid musllinux tag."
    else if platform.libc != "musl" then false
    else if libc.pname != "musl" then false
    else if compareVersions "${sysMajor}.${sysMinor}" "${tagMajor}.${tagMinor}" < 0 then false
    else if pep599.manyLinuxTargetMachines.${tagArch} != platform.parsed.cpu.name then false
    else true;

}
