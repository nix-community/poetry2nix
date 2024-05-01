{ poetry2nix, python3, runCommand, lib }:
let
  fakeDir = runCommand "artificial-dir-for-test" { } ''
    mkdir -p $out
    cp ${./pyproject.toml} $out/pyproject.toml
    cp ${./poetry.lock} $out/poetry.lock
    echo "print('did not infinitely recurse')" > $out/thing.py
  '';
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = poetry2nix.cleanPythonSources {
      src = fakeDir;
    };
  };
in
runCommand "infrec-test" { } ''
  ${env}/bin/python ${fakeDir}/thing.py > $out
''
