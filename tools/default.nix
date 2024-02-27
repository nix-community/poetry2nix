{ pkgs, poetry2nix }:
let
  inherit (pkgs) lib;

  srcPath = builtins.toString ../.;
in
{

  flamegraph =
    let
      runtimeDeps = lib.makeBinPath [
        pkgs.flamegraph
        pkgs.python3
        pkgs.nix
      ];
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
      python3 ${pkgs.nix.src}/contrib/stack-collapse.py $workdir/traceFile > $workdir/traceFile.folded
      flamegraph.pl $workdir/traceFile.folded > poetry2nix-flamegraph.svg
    '';

  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };

  py2-astparse = pkgs.writeScriptBin "py2-astparse" ''
    #!${pkgs.python2.interpreter}
    # Used as a smoke test for Python2 compatibility in Python files
    import sys
    import ast

    if __name__ == "__main__":
        with open(sys.argv[1]) as f:
            try:
                ast.parse(f.read())
            except Exception as e:
                sys.stderr.write("Error parsing '{}':\n".format(sys.argv[1]))
                sys.stderr.flush()
                raise
  '';

}
