{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
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
runCommand "editable-test"
  { } ''
  cp -r --no-preserve=mode ${./src} src
  echo 'print("Changed")' > src/trivial/__main__.py
  if [[ $(${env}/bin/python -m trivial) != "Changed" ]]; then
    echo "Package wasn't editable!"
    exit 1
  fi
  touch $out
'' // { inherit env; }
