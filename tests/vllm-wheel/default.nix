{
  poetry2nix,
  python311,
  runCommand,
}:

let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
in
runCommand "vllm-wheel" { } ''
  export HF_HOME="$(mktemp -d)"
  ${env}/bin/python -c 'import vllm; print(vllm.__version__)' > $out
''
