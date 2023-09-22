{ poetry2nix }:
poetry2nix.mkPoetryEnv {
  projectDir = ./.;
}
