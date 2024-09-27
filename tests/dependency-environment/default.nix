{ curl, lib, poetry2nix, python311, runCommand }:
let
  app = poetry2nix.mkPoetryApplication {
    python = python311;
    src = lib.cleanSource ./.;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };

  # Test support for overriding the app passed to the environment
  overridden = app.overrideAttrs (old: {
    name = "${old.pname}-overridden-${old.version}";
  });
  depEnv = app.dependencyEnv.override {
    app = overridden;
  };
in
runCommand "dependency-environment-test"
{ } ''
  ${depEnv}/bin/gunicorn --bind=unix:socket trivial:app &
  sleep 1
  ${curl}/bin/curl --unix-socket socket localhost
  touch $out
''
