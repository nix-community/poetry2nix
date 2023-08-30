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
  url_nix_store = py.python.pkgs.de-dep-news-trf.src;
  url_is_wheel = url_nix_store.isWheel or false;
  output =
    runCommand "app_eval"
      { } ''
      "${app}/bin/test" >$out
    '';
in
# HACK: This doesn't get recognized as isWheel, it's a string pointing to nix-store
assert lib.strings.hasSuffix "whl" url_nix_store;
assert (builtins.readFile output) == "Dies ist ein Testsatz.\n"; (lib.warnIf (!url_is_wheel) "url should be recognized as isWheel, likely darwin only issue"
  app)
