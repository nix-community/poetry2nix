{ poetry2nix, python3 }:

poetry2nix.mkPoetryApplication {
  python = python3;
  projectDir = ./.;
}
