{ poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
    overrides = [
      (final: prev: {
        trivial = prev.trivial.overridePythonAttrs (attrs: {
          nativeBuildInputs = attrs.nativeBuildInputs or [ ] ++ [ final.poetry-core ];
        });
      })
      poetry2nix.defaultPoetryOverrides
    ];
  };
in
runCommand "git-subdirectory" { } ''
  ${env}/bin/python -c 'import trivial'
  touch $out
''
