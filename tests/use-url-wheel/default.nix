{ lib
, poetry2nix
, python3
, runCommand
,
}:
let
  args = {
    python = python3;
    projectDir = ./.;
    preferWheels = true;
  };
  py = poetry2nix.mkPoetryPackages args;
  app = poetry2nix.mkPoetryApplication args;
  url_nix_store = py.python.pkgs.de-core-news-sm.src;
  url_is_wheel = url_nix_store.isWheel or false;
  output =
    runCommand "app_eval"
      { } ''
      "${app}/bin/test" >$out
    '';
  is_wheel_attr_test = x: lib.warnIf (!url_is_wheel)
    "url should resolve to have src with .isWheel, likely darwin only issue"
    x;
  is_wheel_test = x: assert lib.strings.hasSuffix "whl" url_nix_store; x;
  # HACK: CI fails because https://github.com/nix-community/poetry2nix/pull/1109
  # seems to want libcuda to be installed/managed separately, run it on impure
  # shell and we are all good.
  integration_run_test = x: assert (builtins.readFile output) == "Dies ist ein Testsatz.\n"; x;
  app_builds = x: assert lib.isDerivation app; x;

  constraintOutput = x: lib.pipe x [ is_wheel_attr_test is_wheel_test app_builds ];

in
constraintOutput
  app
