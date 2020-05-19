{ pkgs }:
self: super: {

  alembic = super.alembic.overrideAttrs (
    _: {
      src = pkgs.fetchgit {
        url = "https://github.com/sqlalchemy/alembic.git";
        rev = "8d6bb007a4de046c4d338f4b79b40c9fcbf73ab7";
        sha256 = "15q4dsn4b1cjf1a4cxymxl2gzdjnv9zlndk98jmpfhssqsr4ky3w";
      };
    }
  );

}
