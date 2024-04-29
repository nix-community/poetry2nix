/* It is assumed that propagated dependencies are included in the poetryPackages.
  The "certifi" is direct dependency of "requests" library.

  Note: this test assumes that "certifi" lib is going to be a dep of "requests" in the future.
*/
{ poetry2nix, python3, python39 }:
let
  inherit (builtins) elem map;
  drvPythonCurrent = poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python = python3;
  };

  # Test backward compatibility
  drvPythonOldest = poetry2nix.mkPoetryPackages {
    projectDir = ./.;
    python = python39;
  };

  packageNamesCurrent = map (package: package.pname) drvPythonCurrent.poetryPackages;
  packageNamesPythonOldest = map (package: package.pname) drvPythonOldest.poetryPackages;
in
assert builtins.elem "certifi" packageNamesCurrent;
assert builtins.elem "certifi" packageNamesPythonOldest;
drvPythonCurrent.python
