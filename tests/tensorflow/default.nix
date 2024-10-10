{ poetry2nix, python311 }:
poetry2nix.mkPoetryEnv {
  projectDir = ./.;
  python = python311;
  preferWheels = true;
}
