{ pkgs }:
self: super: {

  pyramid-deferred-sqla = super.pyramid-deferred-sqla.overridePythonAttrs (
    _: {
      src = pkgs.fetchgit {
        url = "https://github.com/niteoweb/pyramid_deferred_sqla.git";
        rev = "639b822d16aff7d732a4da2d3752cfdecee00aef";
        sha256 = "0k3azmnqkriy0nz8g2g8fjhfa25i0973pjqhqsfd33ir0prwllz7";
      };
    }
  );

}
