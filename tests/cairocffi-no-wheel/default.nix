{
  poetry2nix,
  python3,
  pkgs,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = false;
  };
in
assert !(env.python.pkgs.cairocffi.src.isWheel or false);
runCommand "cairocffi-no-wheel" { } ''
  ${env}/bin/python -c 'import cairocffi; print(cairocffi.__version__)' > $out
''
