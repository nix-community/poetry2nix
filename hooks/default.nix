{ python
, buildPackages
, makeSetupHook
, wheel
, pip
, pkgs
, lib
}:
let
  inherit (python.pythonForBuild.pkgs) callPackage;
  pythonInterpreter = python.pythonForBuild.interpreter;
  pythonSitePackages = python.sitePackages;

  nonOverlayedPython = pkgs.python3.pythonForBuild.withPackages (ps: [ ps.tomlkit ]);
  makeRemoveSpecialDependenciesHook = { fields, kind }:
    nonOverlayedPython.pkgs.callPackage
      (
        _:
        makeSetupHook
          {
            name = "remove-path-dependencies.sh";
            substitutions = {
              # NOTE: We have to use a non-overlayed Python here because otherwise we run into an infinite recursion
              # because building of tomlkit and its dependencies also use these hooks.
              pythonPath = nonOverlayedPython.pkgs.makePythonPath [ nonOverlayedPython ];
              pythonInterpreter = nonOverlayedPython.interpreter;
              pyprojectPatchScript = "${./pyproject-without-special-deps.py}";
              inherit fields;
              inherit kind;
            };
          } ./remove-special-dependencies.sh
      )
      { };
  makeSetupHookArgs = deps:
    if lib.elem "deps" (builtins.attrNames (builtins.functionArgs makeSetupHook)) then
      { inherit deps; }
    else
      { propagatedBuildInputs = deps; };
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


  pipBuildHook = callPackage
    (
      { pip, wheel }:
      makeSetupHook
        ({
          name = "pip-build-hook.sh";
          substitutions = {
            inherit pythonInterpreter pythonSitePackages;
          };
        } // (makeSetupHookArgs [ pip wheel ])) ./pip-build-hook.sh
    )
    { };

  poetry2nixFixupHook = callPackage
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
            ];
          };
        } ./fixup-hook.sh
    )
    { };

  # When the "wheel" package itself is a wheel the nixpkgs hook (which pulls in "wheel") leads to infinite recursion
  # It doesn't _really_ depend on wheel though, it just copies the wheel.
  wheelUnpackHook = callPackage
    (_:
      makeSetupHook
        {
          name = "wheel-unpack-hook.sh";
        } ./wheel-unpack-hook.sh
    )
    { };
}
