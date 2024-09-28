{ poetry2nix, python311, runCommand, curl }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python311;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;

    editablePackageSources = {
      # Usually this would be trivial = ./src
      # But we use this here to be able to test it
      # in a derivation build
      trivial = "/build/src";
    };
  };
in
runCommand "editable-egg-test"
{ } ''
  cp -r --no-preserve=mode ${./src} src

  run() {
    ${env}/bin/gunicorn --bind=unix:socket --paste ${./paste.ini} &
    sleep 1
    result=$(${curl}/bin/curl --unix-socket socket localhost)
    echo "Got: $result" >&2
    kill $!
    echo "$result"
  }

  if [[ "$(run)" != "Original" ]]; then
    echo "Package didn't return Original string"
    exit 1
  fi

  sed -i 's/Original/Changed/' src/trivial/__init__.py

  if [[ "$(run)" == "Original" ]]; then
    echo "Package wasn't editable, still returning the Original string even after the source was changed"
    exit 1
  fi

  touch $out
''
