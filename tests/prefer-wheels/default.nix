{ lib, poetry2nix, python3, runCommand }:
let

  app = poetry2nix.mkPoetryApplication {
    projectDir = ./.;
    preferWheels = true;
  };

  url = lib.elemAt app.passthru.python.pkgs.tensorflow.src.urls 0;

in
assert lib.hasSuffix "whl" url; runCommand "prefer-wheels" {} ''
  touch $out
''
