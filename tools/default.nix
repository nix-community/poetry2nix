{ pkgs ? import <nixpkgs> {
    overlays = [
      (import ../overlay.nix)
    ];
  }
}:

let
  inherit (pkgs) lib;

in
{

  flamegraph = let
    runtimeDeps = lib.makeBinPath [
      pkgs.flamegraph
      pkgs.python3
      pkgs.nix
    ];

    nixSrc = pkgs.runCommandNoCC "${pkgs.nix.name}-sources" {} ''
      mkdir $out
      tar -x --strip=1 -f ${pkgs.nix.src} -C $out
    '';

    srcPath = builtins.toString ../.;

  in
    pkgs.writeScriptBin "poetry2nix-flamegraph" ''
      #!${pkgs.runtimeShell}
      export PATH=${runtimeDeps}:$PATH

      workdir=$(mktemp -d)
      function cleanup {
        rm -rf "$workdir"
      }
      trap cleanup EXIT

      # Run once to warm up
      nix-instantiate --expr '(import <nixpkgs> { overlays = [ (import ${srcPath + "/overlay.nix"}) ]; })' -A poetry
      nix-instantiate --trace-function-calls --expr '(import <nixpkgs> { overlays = [ (import ${srcPath + "/overlay.nix"}) ]; })' -A poetry 2> $workdir/traceFile
      python3 ${nixSrc}/contrib/stack-collapse.py $workdir/traceFile > $workdir/traceFile.folded
      flamegraph.pl $workdir/traceFile.folded > poetry2nix-flamegraph.svg
    '';

}
