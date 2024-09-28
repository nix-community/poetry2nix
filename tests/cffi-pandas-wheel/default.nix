{ poetry2nix, python311, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  isWheelCffi = env.python.pkgs.cffi.src.isWheel;
  isWheelPandas = env.python.pkgs.pandas.src.isWheel;
in
assert isWheelCffi; assert isWheelPandas; runCommand "cffi-pandas-test" { } ''
  ${env}/bin/python -c 'import cffi, pandas; print(cffi.__version__); print(pandas.__version__)' > $out
''
