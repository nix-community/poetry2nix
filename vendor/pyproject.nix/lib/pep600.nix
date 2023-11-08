{ lib, pep599, ... }:
let
  inherit (builtins) match elemAt compareVersions splitVersion;
  inherit (lib) fix;

in
fix (self: {
  /* Map legacy (pre PEP-600) platform tags to PEP-600 compliant ones.

     https://peps.python.org/pep-0600/#legacy-manylinux-tags

     Type: legacyAliases.${tag} :: AttrSet -> string

     Example:
     # legacyAliases."manylinux1_x86_64" or "manylinux1_x86_64"
     "manylinux_2_5_x86_64"
  */
  legacyAliases = {
    manylinux1_x86_64 = "manylinux_2_5_x86_64";
    manylinux1_i686 = "manylinux_2_5_i686";
    manylinux2010_x86_64 = "manylinux_2_12_x86_64";
    manylinux2010_i686 = "manylinux_2_12_i686";
    manylinux2014_x86_64 = "manylinux_2_17_x86_64";
    manylinux2014_i686 = "manylinux_2_17_i686";
    manylinux2014_aarch64 = "manylinux_2_17_aarch64";
    manylinux2014_armv7l = "manylinux_2_17_armv7l";
    manylinux2014_ppc64 = "manylinux_2_17_ppc64";
    manylinux2014_ppc64le = "manylinux_2_17_ppc64le";
    manylinux2014_s390x = "manylinux_2_17_s390x";
  };

  /* Check if a manylinux tag is compatible with a given stdenv.

     Type: manyLinuxTagCompatible :: AttrSet -> derivation -> string -> bool

     Example:
     # manyLinuxTagCompatible pkgs.stdenv.targetPlatform pkgs.stdenv.cc.libc "manylinux_2_5_x86_64"
     true
  */
  manyLinuxTagCompatible =
    # Platform attrset (`lib.systems.elaborate "x86_64-linux"`)
    platform:
    # Libc derivation
    libc:
    # Platform tag string
    tag:
    let
      tag' = self.legacyAliases.${tag} or tag;
      m = match "manylinux_([0-9]+)_([0-9]+)_(.*)" tag';
      mAt = elemAt m;
      tagMajor = mAt 0;
      tagMinor = mAt 1;
      tagArch = mAt 2;
      sysVersion' = elemAt (splitVersion libc.version);
      sysMajor = sysVersion' 0;
      sysMinor = sysVersion' 1;
    in
    if m == null then throw "'${tag'}' is not a valid manylinux tag."
    else if platform.libc != "glibc" then false
    else if libc.pname != "glibc" then false
    else if compareVersions "${sysMajor}.${sysMinor}" "${tagMajor}.${tagMinor}" < 0 then false
    else if pep599.manyLinuxTargetMachines.${tagArch} != platform.parsed.cpu.name then false
    else true;

})
