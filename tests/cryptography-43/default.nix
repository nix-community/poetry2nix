{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "cryptography-test" { } ''
  ${env}/bin/python -c 'import cryptography; print(cryptography.__version__)' > $out
''
