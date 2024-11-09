{ lib, poetry2nix, python311, stdenv }:
let
  args = {
    python = python311;
    projectDir = ./.;
    preferWheels = true;
  };
  py = poetry2nix.mkPoetryPackages args;
  app = poetry2nix.mkPoetryApplication args;
  url_nix_store = py.python.pkgs.de-core-news-sm.src;
  url_is_wheel = url_nix_store.isWheel or false;
  is_wheel_attr_test = x: lib.warnIf (!stdenv.isLinux && !url_is_wheel)
    "url should resolve to have src with .isWheel"
    x;
  is_wheel_test = x: assert lib.strings.hasSuffix "whl" url_nix_store; x;
  app_builds = x: assert lib.isDerivation app; x;
in
lib.pipe app [ is_wheel_attr_test is_wheel_test app_builds ]
