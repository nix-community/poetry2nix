{ poetry2nix, runCommand, python311 }:
let
  mkEnv = preferWheel: poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python311;
    overrides = poetry2nix.overrides.withDefaults (
      _: prev: {
        matplotlib = prev.matplotlib.override {
          inherit preferWheel;
        };
      }
    );
  };
in
runCommand "matplotlib-3-6-test" { } ''
  ${mkEnv true}/bin/python -c 'import matplotlib'
  ${mkEnv false}/bin/python -c 'import matplotlib'
  touch $out
''
