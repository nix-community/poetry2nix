{ poetry2nix, python3, runCommand }:
let
  env-wheel = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  env-no-wheel = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
  };
  isWheel = env-wheel.python.pkgs.colour.src.isWheel or false;
  isNotWheel = env-no-wheel.python.pkgs.colour.src.isWheel or false;
in
assert isWheel; assert !isNotWheel; runCommand "colour-test" { } ''
  ${env-wheel}/bin/python -c 'import colour; print("wheel")' > $out
  ${env-no-wheel}/bin/python -c 'import colour; print("source")' >> $out
''
