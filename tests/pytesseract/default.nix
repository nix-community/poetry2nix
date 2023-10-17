{ poetry2nix, runCommand, python3 }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  py = env.python;
in
runCommand "pytesseract-test" { } ''
  ${env}/bin/python -c 'import pytesseract; print(pytesseract.get_tesseract_version())' > $out
''
