{ poetry2nix, runCommand }:
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
