{ lib }:
lib.fix (self: {
  lib = import ./lib { inherit lib; };
  build = import ./build {
    pyproject-nix = self;
    inherit lib;
  };
  packages =
    { callPackage }:
    {
      build-editable = callPackage ./build/editable { };
    };
})
