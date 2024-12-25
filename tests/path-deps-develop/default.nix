{
  poetry2nix,
  python3,
  runCommand,
}:

let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
    editablePackageSources = {
      dep1 = null;
    };

    overrides = poetry2nix.overrides.withDefaults (
      final: prev: {
        dep1 = prev.dep1.overridePythonAttrs (old: {
          buildInputs = (old.buildInputs or [ ]) ++ [ final.setuptools ];
        });
      }
    );
  };

in
runCommand "path-deps-develop-import" { } ''
  echo using ${env}
  ${env}/bin/python -c 'import dep1'
  echo $? > $out
''
