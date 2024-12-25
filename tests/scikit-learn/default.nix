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
    overrides = poetry2nix.overrides.withDefaults (
      _: prev: {
        numpy = prev.numpy.override {
          preferWheel = true;
        };
        scipy = prev.scipy.override {
          preferWheel = true;
        };
        pandas = prev.pandas.override {
          preferWheel = true;
        };
      }
    );
  };
in
runCommand "scikit-learn-test" { } ''
  ${env}/bin/python -c 'import sklearn; print(sklearn.__version__)' > $out
''
