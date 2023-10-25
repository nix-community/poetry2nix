{ curl, lib, poetry2nix, python3, runCommand }:
let
  app = poetry2nix.mkPoetryApplication {
    python = python3;
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
runCommand "app-env-test"
{ } ''
  ${depEnv}/bin/gunicorn --bind=unix:socket trivial:app &
  sleep 1
  ${curl}/bin/curl --unix-socket socket localhost
  touch $out
''
