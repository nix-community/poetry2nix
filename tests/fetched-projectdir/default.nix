{ pkgs, poetry2nix, python39, fetchFromGitHub }:

let
  rawProjectDir = fetchFromGitHub {
    owner = "nix-community";
    repo = "pynixutil";
    rev = "d27d778dc9109227b927ab88fedb2e3c2d6a7265";
    sha256 = "sha256-+Ey384Nz6hvDZAA5OYO0EAGkGjY9Kz4134CRIMjEeyg=";
  };
  # patch the project dir to use poetry-core instead of poetry
  projectDir = pkgs.runCommand "pyproject-dir" { } ''
    mkdir -p $out
    cp -r ${rawProjectDir}/* $out
    sed \
      -i $out/pyproject.toml \
      -e 's/poetry>=0\.12/poetry-core/g' \
      -e 's/poetry\.masonry/poetry.core.masonry/g'
  '';
in
poetry2nix.mkPoetryApplication {
  inherit projectDir;
  python = python39;
}
