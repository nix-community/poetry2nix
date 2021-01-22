{ pkgs ? import <nixpkgs> { } }:
let
  poetry = pkgs.callPackage ../pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
  poetry2nix = import ./.. { inherit pkgs;inherit poetry; };
  pep425 = pkgs.callPackage ../pep425.nix { };
  pep425Python37 = pkgs.callPackage ../pep425.nix { python = pkgs.python37; };
  pep425OSX = pkgs.callPackage ../pep425.nix { isLinux = false; };
  skipTests = builtins.filter (t: builtins.typeOf t != "list") (builtins.split "," (builtins.getEnv "SKIP_TESTS"));
  callTest = test: attrs: pkgs.callPackage test ({ inherit poetry2nix; } // attrs);
in
builtins.removeAttrs
{
  trivial = callTest ./trivial { };
  composable-defaults = callTest ./composable-defaults { };
  override = callTest ./override-support { };
  override-default = callTest ./override-default-support { };
  top-packages-1 = callTest ./common-pkgs-1 { };
  top-packages-2 = callTest ./common-pkgs-2 { };
  pep425 = pkgs.callPackage ./pep425 { inherit pep425;inherit pep425OSX;inherit pep425Python37; };
  env = callTest ./env { };
  git-deps = callTest ./git-deps { };
  # git-deps-pinned = callTest ./git-deps-pinned { };
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
