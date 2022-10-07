{ lib, poetry2nix, python39, fetchFromGitHub }:

poetry2nix.mkPoetryApplication {
  projectDir = fetchFromGitHub {
    owner = "nix-community";
    repo = "pynixutil";
    rev = "d27d778dc9109227b927ab88fedb2e3c2d6a7265";
    sha256 = "sha256-+Ey384Nz6hvDZAA5OYO0EAGkGjY9Kz4134CRIMjEeyg=";
  };
  python = python39;
}
