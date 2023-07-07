{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
}:
let
  inherit (pkgs) python3;
in
pkgs.stdenv.mkDerivation {
  pname = "poetry2nix-cli";
  version = "0";

  buildInputs = [
    (python3.withPackages (ps: [ ps.toml ]))
  ];

  nativeBuildInputs = [
    pkgs.makeWrapper
  ];

  src = ./bin;

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild
    patchShebangs poetry2nix
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    mv poetry2nix $out/bin

    wrapProgram $out/bin/poetry2nix --prefix PATH ":" ${lib.makeBinPath [
      pkgs.nix-prefetch-git
    ]}

    runHook postInstall
  '';

  meta = {
    homepage = "https://github.com/nix-community/poetry2nix";
    description = "CLI to supplement sha256 hashes for git dependencies";
    license = lib.licenses.mit;
    maintainers = [ lib.maintainers.adisbladis ];
  };

}
