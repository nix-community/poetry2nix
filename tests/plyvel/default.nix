{
  lib,
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
runCommand "plyvel-test" { } ''
  "${lib.getExe env}" -c 'import plyvel; print(plyvel.__version__)' > $out
''
