{ lib, poetry2nix, python37, runCommandNoCC }:
let
  drv = poetry2nix.mkPoetryApplication {
    python = python37;
    projectDir = ./.;
  };
in
assert lib.strings.hasSuffix ".egg" (lib.elemAt drv.passthru.python.pkgs.pyasn1.src.urls 0);
runCommandNoCC "egg-test" {} "touch $out"
