{ lib, poetry2nix, python3, runCommand, writeText }:

let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    groups = [
      "dev"
      "foo"
    ];
  };

  alembicFailImportCheck = writeText "alembic-import-fail.py" ''
    try:
        import alembic
    except ImportError:
        pass
    else:
        raise ValueError("Alembic import expected to fail!")
  '';

in
runCommand "dependency-groups" { } ''
  ${env}/bin/python -c 'import flask'
  ${env}/bin/python -c 'import requests'
  ${env}/bin/python ${alembicFailImportCheck}
  touch $out
''
