{ poetry2nix, python310 }:
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
  python = python310;
}
