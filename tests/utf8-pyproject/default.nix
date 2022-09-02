{ lib, poetry2nix, python39 }:

poetry2nix.mkPoetryApplication {
  python = python39;
  projectDir = ./.;
}
