{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "cyclonedx-and-sarif-tools-test" { } ''
  export HOME=$(mktemp -d)
  ${env}/bin/python -c 'import cyclonedx; print(f"cyclonedx {cyclonedx.__version__}")' | tee $out
  ${env}/bin/sarif --version | tee -a $out
''
