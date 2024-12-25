{
  lib,
  poetry2nix,
  python310,
}:

poetry2nix.mkPoetryApplication {
  python = python310;
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
