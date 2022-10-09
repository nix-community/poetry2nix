{ lib, poetry2nix, python310 }:

poetry2nix.mkPoetryApplication {
  python = python310;
  pyproject = ./pyproject.toml;
  poetrylock = ./poetry.lock;
  src = lib.cleanSource ./.;
  checkGroups = [ "test" ];

  checkPhase = ''
    runHook preCheck
    pytest
    runHook postCheck
  '';
}
