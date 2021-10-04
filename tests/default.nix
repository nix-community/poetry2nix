let
  sources = import ../nix/sources.nix;
in
{ pkgs ? import sources.nixpkgs {
    overlays = [
      (import ../overlay.nix)
    ];
  }
}:
let
  poetry = pkgs.callPackage ../pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
  poetry2nix = import ./.. { inherit pkgs;inherit poetry; };
  poetryLib = import ../lib.nix { inherit pkgs; lib = pkgs.lib; stdenv = pkgs.stdenv; };
  pep425 = pkgs.callPackage ../pep425.nix { inherit poetryLib; };
  pep425Python37 = pkgs.callPackage ../pep425.nix { inherit poetryLib; python = pkgs.python37; };
  pep425OSX = pkgs.callPackage ../pep425.nix { inherit poetryLib; isLinux = false; };
  skipTests = builtins.filter (t: builtins.typeOf t != "list") (builtins.split "," (builtins.getEnv "SKIP_TESTS"));
  callTest = test: attrs: pkgs.callPackage test ({ inherit poetry2nix; } // attrs);
in
builtins.removeAttrs
{
  trivial = callTest ./trivial { };
  legacy = callTest ./legacy { };
  composable-defaults = callTest ./composable-defaults { };
  override = callTest ./override-support { };
  override-default = callTest ./override-default-support { };
  top-packages-1 = callTest ./common-pkgs-1 { };
  top-packages-2 = callTest ./common-pkgs-2 { };
  pep425 = pkgs.callPackage ./pep425 { inherit pep425;inherit pep425OSX;inherit pep425Python37; };
  env = callTest ./env { };
  pytest-randomly = callTest ./pytest-randomly { };
  file-src-deps = callTest ./file-src-deps { };
  file-src-deps-level2 = callTest ./file-src-deps-level2 { };
  file-wheel-deps = callTest ./file-wheel-deps { };
  file-wheel-deps-level2 = callTest ./file-wheel-deps-level2 { };
  git-deps = callTest ./git-deps { };
  git-deps-pinned = callTest ./git-deps-pinned { };
  in-list = callTest ./in-list { };
  cli = poetry2nix;
  path-deps = callTest ./path-deps { };
  path-deps-level2 = callTest ./path-deps-level2 { };
  operators = callTest ./operators { };
  preferWheel = callTest ./prefer-wheel { };
  prefer-wheels = callTest ./prefer-wheels { };
  closure-size = callTest ./closure-size {
    inherit poetry;
    inherit (pkgs) postgresql;
  };
  pyqt5 = callTest ./pyqt5 { };
  eggs = callTest ./eggs { };
  extras = callTest ./extras { };
  source-filter = callTest ./source-filter { };
  canonical-module-names = callTest ./canonical-module-names { };
  wandb = callTest ./wandb { };
  dependency-environment = callTest ./dependency-environment { };
  editable = callTest ./editable { };
  editable-egg = callTest ./editable-egg { };
  ansible-molecule = callTest ./ansible-molecule { };
  mk-poetry-packages = callTest ./mk-poetry-packages { };
  markupsafe2 = callTest ./markupsafe2 { };
  pendulum = callTest ./pendulum { };
  uwsgi = callTest ./uwsgi { };

  # Test building poetry
  inherit poetry;

  poetry-env =
    let
      env = poetry2nix.mkPoetryEnv { projectDir = ../pkgs/poetry; };
    in
    pkgs.runCommand "poetry-env-test" { } ''
      ${env}/bin/python -c 'import requests'
      touch $out
    '';

  # And also test with pypy
  # poetry-pypy = poetry.override { python = pkgs.pypy; };
  # poetry-pypy3 = poetry.override { python = pkgs.pypy3; };

  # manylinux requires nixpkgs with https://github.com/NixOS/nixpkgs/pull/75763
  # Once this is available in 19.09 and unstable we can re-enable the manylinux test
  manylinux = callTest ./manylinux { };
}
  skipTests
