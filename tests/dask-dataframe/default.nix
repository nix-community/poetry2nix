{ poetry2nix, python311, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "dask-dataframe-infinite-recursion-test" { } ''
  ${env}/bin/python -c 'import dask.dataframe as dd; import dask_expr'
  touch $out
''
