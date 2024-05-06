{ poetry2nix, python310, runCommand }:

let
  mkEnv = preferWheel: poetry2nix.mkPoetryEnv {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (
      _: prev: {
        python-magic = prev.python-magic.override {
          inherit preferWheel;
        };
      }
    );
  };
  wheelEnv = mkEnv true;
  srcEnv = mkEnv false;
in
runCommand "python-magic" { } ''
  set -euo pipefail
  ${wheelEnv}/bin/python -c 'import magic' > $out
  ${srcEnv}/bin/python -c 'import magic' >> $out
  touch $out
''
