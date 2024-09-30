{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "shellcheck-py-test" { } ''
  ${env}/bin/python -c 'import shellcheck_py; print(shellcheck_py.__version__)' > $out
''
