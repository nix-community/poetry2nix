{
  poetry2nix,
  python310,
  runCommand,
}:
let
  mkEnv =
    preferWheel:
    poetry2nix.mkPoetryEnv {
      python = python310;
      pyproject = ./pyproject.toml;
      poetrylock = ./poetry.lock;
      overrides = poetry2nix.overrides.withDefaults (
        _: prev: {
          pyogrio = prev.pyogrio.override {
            inherit preferWheel;
          };
          numpy = prev.numpy.override {
            preferWheel = true;
          };
          pandas = prev.pandas.override {
            preferWheel = true;
          };
        }
      );
    };
  wheelEnv = mkEnv true;
  srcEnv = mkEnv false;
in
runCommand "pyogrio-test" { } ''
  set -euo pipefail
  ${wheelEnv}/bin/python -c 'import pyogrio; print(f"wheel: {pyogrio.__version__}")' > $out
  ${srcEnv}/bin/python -c 'import pyogrio; print(f"src: {pyogrio.__version__}")' >> $out
  touch $out
''
