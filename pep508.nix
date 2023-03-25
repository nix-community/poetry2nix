{ pkgs, lib, ... }: python:
e: name: version:
if e == "" then true else builtins.fromJSON (
  builtins.readFile (
    pkgs.runCommand "${name}-${version}-markers.json"
    {
      nativeBuildInputs = [ (python.withPackages (p: [ p.packaging ])) ];
    } ''
      python ${./eval_markers.py} ${lib.escapeShellArg e} > "$out"
    ''
  )
)
