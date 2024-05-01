{ lib, poetry2nix, python3, runCommand }:
{
  envWheel = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
    preferWheels = true;
  };
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    projectDir = ./.;
  };
}
