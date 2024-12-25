{
  python3,
  poetry2nix,
  runCommand,
}:
let
  p = poetry2nix.mkPoetryApplication {
    python = python3;
    src = ./.;
    poetrylock = ./poetry.lock;
    pyproject = ./pyproject.toml;
    overrides = poetry2nix.overrides.withDefaults (
      _final: prev: {
        alembic = prev.alembic.overridePythonAttrs (_old: {
          TESTING_FOOBAR = 42;
        });
      }
    );
  };
in
runCommand "test" { } ''
  x=${builtins.toString p.python.pkgs.alembic.TESTING_FOOBAR}
  [ "$x" = "42" ] || exit 1
  mkdir $out
''
