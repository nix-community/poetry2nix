{ poetry2nix, python310, runCommand }:

let
  mkEnv = preferWheel: poetry2nix.mkPoetryEnv {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (
      _: prev: {
        cmdstanpy = prev.cmdstanpy.override {
          inherit preferWheel;
        };
        numpy = prev.numpy.override {
          preferWheel = true;
        };
        pandas = prev.pandas.override {
          preferWheel = true;
        };
      }
    );
  };
  wheelEnv = mkEnv true;
  srcEnv = mkEnv false;
in
runCommand "cmdstanpy-test" { } ''
  set -euo pipefail
  ${wheelEnv}/bin/python -c 'import cmdstanpy; print(cmdstanpy.__version__)' > $out
  ${srcEnv}/bin/python -c 'import cmdstanpy; print(cmdstanpy.__version__)' >> $out
  touch $out
''
