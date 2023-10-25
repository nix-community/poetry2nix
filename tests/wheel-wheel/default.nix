{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  isWheelWheel = env.python.pkgs.wheel.src.isWheel;
in
assert (!isWheelWheel); runCommand "wheel-wheel-test" { } ''
  ${env}/bin/python -c 'import wheel; print(wheel.__version__)' > $out
''
