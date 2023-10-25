{ poetry2nix }:

poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
