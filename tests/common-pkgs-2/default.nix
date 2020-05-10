{ lib, poetry2nix, python3, preferWheels ? false }:

poetry2nix.mkPoetryApplication {
  name = "common-pkgs-2" + lib.optionalString preferWheels "-wheels";
  python = python3;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  inherit preferWheels;
}
