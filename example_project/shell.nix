with import <nixpkgs> {};

let
  # TODO: Stop propagating PYTHONPATH
  pythonEnv = (python3.withPackages(ps: [
    ps.poetry
  ])).override (args: {
    ignoreCollisions = true;
  });

in mkShell {
  buildInputs = [
    pythonEnv
  ];
}
