{lib, super, pkgs}:
let
  githubHash = rev: {
    
  }.${rev} or lib.fakeHash;
  # we can count on this repo's root to have Cargo.lock (need deligent research)
in super.orjson.overridePythonAttrs (old: if old.src.isWheel or false then {} else rec {
  src = pkgs.fetchFromGitHub {
    owner = "ijl";
    repo = "orjson";
    rev = old.version;
    sha256 = githubHash;
  };
  cargoDeps = pkgs.rustPlatform.importCargoLock {
    lockFile = "${src.out}/Cargo.lock";
  };
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
    pkgs.rustPlatform.cargoSetupHook   # handles `importCargoLock`
    pkgs.rustPlatform.maturinBuildHook # orjson is based on maturin
  ];
  buildInputs = (old.buildInputs or [ ]) ++ lib.optional pkgs.stdenv.isDarwin pkgs.libiconv;
});
