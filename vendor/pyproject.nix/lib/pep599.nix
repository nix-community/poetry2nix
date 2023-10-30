_:

{
  /* Map Nixpkgs CPU values to target machines known to be supported for manylinux* wheels (a.k.a. `uname -m`),
     in nixpkgs found under the attribute `stdenv.targetPlatform.parsed.cpu.name`

     Example:
     # legacyAliases.powerpc64
     "ppc64"
  */
  manyLinuxTargetMachines = {
    x86_64 = "x86_64";
    i686 = "i686";
    aarch64 = "aarch64";
    armv7l = "armv7l";
    ppc64 = "powerpc64";
    ppc64le = "powerpc64le";
    s390x = "s390x";
  };
}
