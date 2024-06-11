{ lib, poetry2nix, python3, stdenv }:
let
  args = {
    python = python3;
    projectDir = ./.;
    preferWheels = true;
  };
  py = poetry2nix.mkPoetryPackages args;
  app = poetry2nix.mkPoetryApplication args;
  url_nix_store = py.python.pkgs.requests.src;
  url_is_wheel = url_nix_store.isWheel or false;
  is_wheel_attr_test = x: lib.warnIf (!stdenv.isLinux && url_is_wheel)
    "url should resolve to a not wheel"
    x;
  is_wheel_test = x: assert lib.strings.hasSuffix "tar.gz" url_nix_store; x;
  app_builds = x: assert lib.isDerivation app; x;
in
lib.pipe app [ is_wheel_attr_test is_wheel_test app_builds ]
