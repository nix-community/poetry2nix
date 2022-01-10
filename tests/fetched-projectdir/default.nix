{ lib, poetry2nix, python39, fetchFromGitHub }:

poetry2nix.mkPoetryApplication {
  projectDir = fetchFromGitHub {
    owner = "schemathesis";
    repo = "schemathesis";
    rev = "v3.12.1";
    sha256 = "sha256-iU1tsA9MKKH/zjuBxD5yExJOPoL2V/OG3WYc9w0do9I=";
  };
  python = python39;
}
