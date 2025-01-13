{
  lib,
  poetry2nix,
  python3,
}:

poetry2nix.mkPoetryApplication {
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  pwd = ./.;
  overrides = poetry2nix.overrides.withDefaults (
    final: prev: {
      trivial = final.addBuildSystem "poetry" prev.trivial;
    }
  );
}
