{ pkgs, lib, poetry2nix, python3 }:

poetry2nix.mkPoetryApplication {
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;

  overrides = poetry2nix.overrides.withDefaults (import ./poetry-git-overlay.nix { inherit pkgs; });

}
