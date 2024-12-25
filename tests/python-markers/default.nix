{
  poetry2nix,
  python3,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
  };
in
runCommand "python-markers-test" { } ''
  ${env}/bin/python -c 'import plum; print(plum.__version__)' > $out
''
