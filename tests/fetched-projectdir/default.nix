{ lib, poetry2nix, python39, fetchFromGitHub }:

poetry2nix.mkPoetryApplication {
  projectDir = fetchFromGitHub {
    owner = "nix-community";
    repo = "pynixutil";
    rev = "91706ca404b6df42d6ee00649d7990465ea3d30b";
    sha256 = "sha256-pAChip8C/9ZwSoT9qox1j54ai35qb/sVhL1nPxmsYVI=";
  };
  python = python39;
}
