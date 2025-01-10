{ poetry2nix, runCommand }:
let
  mkEnv =
    preferWheel:
    poetry2nix.mkPoetryEnv {
      projectDir = ./.;
      overrides = poetry2nix.overrides.withDefaults (
        _: prev: {
          matplotlib = prev.matplotlib.override {
            inherit preferWheel;
          };
        }
      );
    };
in
runCommand "matplotlib-3-9-test" { } ''
  ${mkEnv true}/bin/python -c 'import matplotlib'
  ${mkEnv false}/bin/python -c 'import matplotlib'
  touch $out
''
