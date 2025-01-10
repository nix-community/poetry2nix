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
runCommand "sphinx5-test" { } ''
  ${env}/bin/python -c 'import sphinx; print(sphinx.__version__)' > $out
''
