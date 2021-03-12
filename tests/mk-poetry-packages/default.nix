/* It is assumed that propagated dependencies are included in the poetryPackages.
   The "certifi" is direct dependency of "requests" library.

   Note: this test assumes that "certifi" lib is going to be a dep of "requests" in the future.
*/
{ lib, poetry2nix, python3 }:
let
  inherit (builtins) elem map;
  drv = poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python = python3;
  };
  packageNames = map (package: package.pname) drv.poetryPackages;
in
assert builtins.elem "certifi" packageNames; drv
