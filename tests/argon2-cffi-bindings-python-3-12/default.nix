{ poetry2nix, python312, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
    python = python312;
  };
in
runCommand "argon2-cffi-bindings-python-3-12-test" { } ''
  ${env}/bin/python -c 'import _cffi_backend as backend; print(backend.__version__)' > $out
''
