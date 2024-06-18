{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "soundfile" { } ''
  ${env}/bin/python -c 'import soundfile; print(soundfile.__version__)' > $out
''
