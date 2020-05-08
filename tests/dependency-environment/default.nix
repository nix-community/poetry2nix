{ curl, lib, poetry2nix, python3, runCommand }:
let
  app = poetry2nix.mkPoetryApplication {
    python = python3;
    src = lib.cleanSource ./.;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
  };
in
runCommand "app-env-test" { } ''
  ${app.dependencyEnv}/bin/gunicorn --bind=unix:socket trivial:app &
  sleep 1
  ${curl}/bin/curl --unix-socket socket localhost
  touch $out
''
