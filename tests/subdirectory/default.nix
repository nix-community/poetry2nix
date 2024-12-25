{
  lib,
  poetry2nix,
  postgresql_14,
  runCommandCC,
  stdenv,
}:

let
  env = poetry2nix.mkPoetryEnv { projectDir = ./.; };
in
if stdenv.isDarwin then
  env
else
  runCommandCC "subdirectory-test"
    {
      PSYCOPG_IMPL = "python";
      LD_LIBRARY_PATH = lib.makeLibraryPath [ postgresql_14 ];
    }
    ''
      '${env}/bin/python' -c 'import psycopg'
      touch "$out"
    ''
