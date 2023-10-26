{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
  };
in
runCommand "awsume-test" { } ''
  "${lib.getExe env}" -c 'import awsume; print(awsume.__VERSION__)' > $out
''
