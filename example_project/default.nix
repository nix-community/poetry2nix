with import ../. { };

mkPoetryPackage {
  src = ./.;
  doCheck = false;
}
