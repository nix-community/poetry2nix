{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (_final: prev: {
      threadpoolctl = prev.threadpoolctl.override { preferWheel = true; };
      pandas = prev.pandas.override { preferWheel = true; };
      pyquaternion = prev.pyquaternion.override { preferWheel = true; };
      scikit-learn = prev.scikit-learn.override { preferWheel = true; };
    });
  };
in
runCommand "pep600-test"
{ } ''
  ${env}/bin/python -c 'import open3d; print(open3d.__version__)'
  touch $out
''
