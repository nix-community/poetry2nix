{ lib, poetry2nix, python3 }:

poetry2nix.mkPoetryApplication {
  python = python3;
  projectDir = ./.;

  # Assert expected ignored files not in sources
  preConfigure =
    let
      assertNotExists = name: "! test -f ${name} || (echo ${name} exists && false)";
    in
    ''
      ${assertNotExists "ignored.pyc"}
      ${assertNotExists "__pycache__"}
      ${assertNotExists "testhest"}
    '';
}
