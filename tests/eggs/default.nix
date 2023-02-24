{ lib, poetry2nix, python3, runCommand }:
let
  drv = poetry2nix.mkPoetryApplication {
    python = python3;
    projectDir = ./.;
  };
in
assert lib.strings.hasSuffix ".egg" (lib.elemAt drv.passthru.python.pkgs.pyasn1.src.urls 0);
runCommand "egg-test" { } "touch $out"
