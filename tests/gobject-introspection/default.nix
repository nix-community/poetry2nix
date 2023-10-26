{ pkgs, poetry2nix, python310 }:

poetry2nix.mkPoetryApplication {
  python = python310;
  projectDir = ./.;
  pythonImportsCheck = [ "gobject_introspection_test" ];

  buildInputs = [ pkgs.libnotify ];
  nativeBuildInputs = [ pkgs.gobject-introspection ];
}
