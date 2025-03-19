{ python, stdenv, makeSetupHook, pkgs, lib }:
let
  pythonOnBuildForHost = python.pythonOnBuildForHost or python.pythonForBuild;
  inherit (pythonOnBuildForHost.pkgs) callPackage;
  pythonInterpreter = pythonOnBuildForHost.interpreter;
  pythonSitePackages = python.sitePackages;

  pythonFromPkgs = {
    "3.6" = pkgs.python36;
    "3.7" = pkgs.python37;
    "3.8" = pkgs.python38;
    "3.9" = pkgs.python39;
    "3.10" = pkgs.python310;
    "3.11" = pkgs.python311;
    "3.12" = pkgs.python312;
    "3.13" = pkgs.python313;
  }.${lib.versions.majorMinor python.version};

  nonOverlayedPython = (pythonFromPkgs.pythonOnBuildForHost or pythonFromPkgs.pythonForBuild).withPackages (ps: [ ps.tomlkit ps.pip ]);
  makeRemoveSpecialDependenciesHook =
    { fields
    , kind
      /*
       * A script that takes in --fields-to-remove <fields, nargs="*">, transforms
       * stdin pyproject.toml onto stdout pyproject.toml
       */
    , pyprojectPatchScript ? "${./pyproject-without-special-deps.py}"
    }:
    nonOverlayedPython.pkgs.callPackage
      (
        _:
        makeSetupHook
          {
            name = "remove-path-dependencies.sh";
            substitutions = {
              # NOTE: We have to use a non-overlayed Python here because otherwise we run into an infinite recursion
              # because building of tomlkit and its dependencies also use these hooks.
              # pythonPath = nonOverlayedPython.pkgs.makePythonPath [ nonOverlayedPython ];
              inherit pythonSitePackages;
              inherit pythonInterpreter;
              inherit pyprojectPatchScript;
              inherit fields;
              inherit kind;
            };
          }
          ./remove-special-dependencies.sh
      )
      { };
  makeSetupHookArgs = deps:
    if lib.elem "propagatedBuildInputs" (builtins.attrNames (builtins.functionArgs makeSetupHook))
    then { propagatedBuildInputs = deps; }
    else { inherit deps; };
in
{
  removePathDependenciesHook = makeRemoveSpecialDependenciesHook {
    fields = [ "path" ];
    kind = "path";
  };

  removeGitDependenciesHook = makeRemoveSpecialDependenciesHook {
    fields = [ "git" "branch" "rev" "tag" ];
    kind = "git";
  };

  removeWheelUrlDependenciesHook = makeRemoveSpecialDependenciesHook {
    fields = [ "url" ];
    kind = "wheel-url";
    pyprojectPatchScript = "${./pyproject-without-url-whl.py}";
  };

  pipBuildHook =
    callPackage
      (
        { wheel }:
        makeSetupHook
          ({
            name = "pip-build-hook.sh";
            substitutions = {
              inherit pythonSitePackages;
              inherit pythonInterpreter;
            };
          }
          // (makeSetupHookArgs [ nonOverlayedPython.pkgs.pip wheel ]))
          ./pip-build-hook.sh
      )
      { };

  poetry2nixFixupHook =
    callPackage
      (
        _:
        makeSetupHook
          {
            name = "fixup-hook.sh";
            substitutions = {
              inherit pythonSitePackages;
              filenames = builtins.concatStringsSep " " [
                "pyproject.toml"
                "README.md"
                "LICENSE"
                "CHANGELOG.md"
                "CHANGES.md"
              ];
            };
          }
          ./fixup-hook.sh
      )
      { };

  # As of 2023-03 a newer version of packaging introduced a new behaviour where python-requires
  # cannot contain version wildcards. This behaviour is complaint with PEP440
  #
  # The wildcards are a no-op anyway so we can work around this issue by just dropping the precision down to the last known number.
  poetry2nixPythonRequiresPatchHook =
    callPackage
      (
        _:
        let
          # Python pre 3.9 does not contain the ast.unparse method.
          # We can extract this from Python 3.8 for any
          unparser = stdenv.mkDerivation {
            name = "${python.name}-astunparse";
            inherit (python) src;
            dontConfigure = true;
            dontBuild = true;

            installPhase = ''
              mkdir -p $out/poetry2nix_astunparse
              cp ./Tools/parser/unparse.py $out/poetry2nix_astunparse/__init__.py
            '';
          };

          pythonPath = lib.optional (lib.versionOlder python.version "3.9") unparser;
        in
        makeSetupHook
          {
            name = "require-python-patch-hook.sh";
            substitutions = {
              inherit pythonInterpreter pythonPath;
              patchScript = ./python-requires-patch-hook.py;
            };
          }
          ./python-requires-patch-hook.sh
      )
      { };
}
