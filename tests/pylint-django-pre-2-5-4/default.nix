{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "pylint-django-test" { } ''
  ${env}/bin/python -c 'import pylint_django'
  touch $out
''
