{ python
, buildPackages
, makeSetupHook
, wheel
, pip
, pkgs
}:
let
  callPackage = python.pythonForBuild.pkgs.callPackage;
  pythonInterpreter = python.pythonForBuild.interpreter;
  pythonSitePackages = python.sitePackages;
  nonOverlayedPython = pkgs.python3.pythonForBuild.withPackages (ps: [ ps.tomlkit ]);
in
{
  # NOTE: We have to use a non-overlayed Python here because otherwise we run into an infinite recursion
  # because building of tomlkit and its dependencies also use these hooks.
  removePathDependenciesHook = nonOverlayedPython.pkgs.callPackage
    (
      {}:
      makeSetupHook
        {
          name = "remove-path-dependencies.sh";
          deps = [ ];
          substitutions = {
            pythonInterpreter = nonOverlayedPython.interpreter;
            pyprojectPatchScript = "${./pyproject-without-special-deps.py}";
            fields = [ "path" ];
            kind = "path";
          };
        } ./remove-special-dependencies.sh
    )
    { };

  removeGitDependenciesHook = nonOverlayedPython.pkgs.callPackage
    (
      {}:
      makeSetupHook
        {
          name = "remove-git-dependencies.sh";
          deps = [ ];
          substitutions = {
            pythonInterpreter = nonOverlayedPython.interpreter;
            pyprojectPatchScript = "${./pyproject-without-special-deps.py}";
            fields = [ "git" "branch" "rev" "tag" ];
            kind = "git";
          };
        } ./remove-special-dependencies.sh
    )
    { };

  pipBuildHook = callPackage
    (
      { pip, wheel }:
      makeSetupHook
        {
          name = "pip-build-hook.sh";
          deps = [ pip wheel ];
          substitutions = {
            inherit pythonInterpreter pythonSitePackages;
          };
        } ./pip-build-hook.sh
    )
    { };

  poetry2nixFixupHook = callPackage
    (
      {}:
      makeSetupHook
        {
          name = "fixup-hook.sh";
          deps = [ ];
          substitutions = {
            inherit pythonSitePackages;
            filenames = builtins.concatStringsSep " " [
              "pyproject.toml"
              "README.md"
            ];
          };
        } ./fixup-hook.sh
    )
    { };

  # When the "wheel" package itself is a wheel the nixpkgs hook (which pulls in "wheel") leads to infinite recursion
  # It doesn't _really_ depend on wheel though, it just copies the wheel.
  wheelUnpackHook = callPackage
    ({}:
      makeSetupHook
        {
          name = "wheel-unpack-hook.sh";
          deps = [ ];
        } ./wheel-unpack-hook.sh
    )
    { };
}
