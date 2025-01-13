{
  poetry2nix,
  python3,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "avro-python3-test" { } ''
  ${env}/bin/python -c 'import avro; print(avro.__version__)' > $out
''
