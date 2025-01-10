{ pkgs }:
_final: prev: {

  alembic = prev.alembic.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/sqlalchemy/alembic.git";
      rev = "8d6bb007a4de046c4d338f4b79b40c9fcbf73ab7";
      sha256 = "15q4dsn4b1cjf1a4cxymxl2gzdjnv9zlndk98jmpfhssqsr4ky3w";
    };
  });

  colorama = prev.colorama.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/tartley/colorama.git";
      rev = "4321bbfda9aa190acdad05eb901d3b59439f0ec9";
      sha256 = "1z88yl4r4g6yv29rw0q7zwylgx9zss360n3s9v07macvv50cb452";
    };
  });

  s3transfer = prev.s3transfer.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/boto/s3transfer.git";
      rev = "b2b6c44cb283e134f6bf9fecad7ff5ee28df793d";
      sha256 = "1dzjzfxp9rkrh1s6ic22kwmr00hqrgz0da330vydlfpmcqgyp1fy";
    };
  });

}
