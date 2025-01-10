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
    preferWheels = true;
  };
in
runCommand "shapely-wheel-test" { } ''
  ${env}/bin/python -c 'import shapely, shapely.geos; print(shapely.__version__)' > $out
''
