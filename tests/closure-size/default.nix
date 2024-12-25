{
  lib,
  poetry2nix,
  poetry,
  postgresql,
}:
poetry2nix.mkPoetryApplication {
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  pwd = ./.;

  inherit poetry;

  # Make sure these packages are missing from runtime closure
  disallowedRequisites = [
    poetry
    postgresql.stdenv.cc.cc
    postgresql.out
  ];
}
