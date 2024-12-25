{
  poetry2nix,
  python3,
  runCommand,
}:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  py = env.python;
  pkg = py.pkgs.soundfile;
  isSoundfileWheel = pkg.src.isWheel;
in
assert isSoundfileWheel;
runCommand "soundfile-wheel" { } ''
  ${env}/bin/python -c 'import soundfile; print(soundfile.__version__)' > $out
''
