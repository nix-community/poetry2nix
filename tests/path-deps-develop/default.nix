{ poetry2nix, python3, runCommand }:

let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
    editablePackageSources = {
      dep1 = null;
    };

    overrides = poetry2nix.overrides.withDefaults (self: super: {
      dep1 = super.dep1.overridePythonAttrs (old: {
        buildInputs = (old.buildInputs or [ ]) ++ [ self.setuptools ];
      });
    });
  };

in
runCommand "path-deps-develop-import" { } ''
  echo using ${env}
  ${env}/bin/python -c 'import dep1'
  echo $? > $out
''
