{ poetry2nix
, runCommand
,
}:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "procrastinate-test" { } ''
  ${env}/bin/procrastinate --version > $out
''
