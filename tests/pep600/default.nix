{ poetry2nix, python310, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    overrides = poetry2nix.overrides.withDefaults (_: super: {
      threadpoolctl = super.threadpoolctl.override { preferWheel = true; };
      pandas = super.pandas.override { preferWheel = true; };
      pyquaternion = super.pyquaternion.override { preferWheel = true; };
      scikit-learn = super.scikit-learn.override { preferWheel = true; };
    });
  };
in
runCommand "pep600-test"
{ } ''
  ${env}/bin/python -c 'import open3d; print(open3d.__version__)'
  touch $out
''
