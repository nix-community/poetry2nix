{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  isPyArrowWheel = env.python.pkgs.pyarrow.src.isWheel;
in
assert isPyArrowWheel; runCommand "pyarrow-test" { } ''
  ${env}/bin/python -c 'import pyarrow; print(pyarrow.__version__)' > $out
''
