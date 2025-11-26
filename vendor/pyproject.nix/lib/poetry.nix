{
  lib,
  pep440,
  pep508,
  pep518,
  pypa,
  ...
}:

lib.fix (
  self:
  let
    inherit (builtins)
      match
      elemAt
      foldl'
      typeOf
      attrNames
      head
      tail
      mapAttrs
      length
      filter
      split
      concatStringsSep
      ;
    inherit (lib) optionalAttrs concatLists;
    inherit (import ./lib.nix { inherit lib; }) splitComma;

    # Translate author from a string like "Name <email>" to a structured set as defined by PEP-621.
    translateAuthor =
      a:
      let
        m = match "^(.+) <(.+)>$" a;
      in
      assert m != null;
      {
        name = elemAt m 0;
        email = elemAt m 1;
      };

    # Normalize dependecy from poetry dependencies table from (string || set) -> set
    normalizeDep =
      name: dep:
      (
        let
          type = typeOf dep;
        in
        if type == "string" then
          {
            inherit name;
            version = dep;
          }
        else if type == "set" then
          dep // { inherit name; }
        else
          throw "Unexpected type: ${type}"
      );

    # Rewrite the right hand side version for caret comparisons according to the rules laid out in
    # https://python-poetry.org/docs/dependency-specification/#caret-requirements
    rewriteCaretRhs =
      release:
      let
        state =
          foldl'
            (
              state: v:
              let
                nonzero = state.nonzero || v != 0;
              in
              state
              // {
                release = state.release ++ [
                  (
                    if nonzero && !state.nonzero then
                      (v + 1)
                    else if nonzero then
                      0
                    else
                      v
                  )
                ];
                inherit nonzero;
              }
            )
            {
              release = [ ];
              nonzero = false;
            }
            release;
      in
      if !state.nonzero then ([ (head state.release + 1) ] ++ tail state.release) else state.release;

    # Poetry dependency tables are of mixed types:
    # [tool.poetry.dependencies]
    # python = "^3.8"
    # cachecontrol = { version = "^0.13.0", extras = ["filecache"] }
    # foo = [
    #     {version = "<=1.9", python = ">=3.6,<3.8"},
    #     {version = "^2.0", python = ">=3.8"}
    # ]
    #
    # These are all valid. Normalize the input to a list of:
    # [
    #   { name = "python"; version = "^3.8"; }
    #   { name = "cachecontrol"; version = "^0.13.0"; extras = ["filecache"]; }
    #   { name = "foo"; version = "<=1.9";  python = ">=3.6,<3.8"; }
    #   { name = "foo"; version = "^2.0"; python = ">=3.8"; }
    # ]
    normalizeDependendenciesToList =
      deps:
      foldl' (
        acc: name:
        acc
        ++ (
          let
            dep = deps.${name};
          in
          if typeOf dep == "list" then map (normalizeDep name) dep else [ (normalizeDep name dep) ]
        )
      ) [ ] (attrNames deps);

    dummyMarker = {
      type = "bool";
      value = true;
    };

    # Analogous to pep508.parseString
    parseDependency =
      dep:
      let
        # Poetry has Python as a separate field in the structured dependency object.
        # This is non-standard. Rewrite these expressions as a nested set of logical ANDs that
        # looks like regular parsed markers as if they were standard PEP-508, just written in a bit of a funky
        # nested way that no human would do.
        markers =
          foldl'
            (rhs: pyCond: {
              type = "boolOp";
              op = "and";
              lhs = {
                type = "compare";
                inherit (pyCond) op;
                lhs = {
                  type = "variable";
                  value = "python_version";
                };
                rhs = {
                  type = "version";
                  value = pyCond.version;
                };
              };
              inherit rhs;
            })
            (
              # Encode no markers as a marker that always evaluates to true to simplify fold logi above.
              if dep ? markers then pep508.parseMarkers dep.markers else dummyMarker
            )
            (if dep ? python then self.parseVersionConds dep.python else [ ]);

      in
      {
        name = pypa.normalizePackageName dep.name;
        conditions = if dep ? version then self.parseVersionConds dep.version else [ ];
        extras = dep.extras or [ ];
        url = dep.url or null;
        markers = if markers == dummyMarker then null else markers;
      };

  in
  {
    /*
      Translate a Pyproject.toml from Poetry to PEP-621 project metadata.
      This function transposes a PEP-621 project table on top of an existing Pyproject.toml populated with data from `tool.poetry`.
      Notably does not translate dependencies/optional-dependencies.

      For parsing dependencies from Poetry see `lib.poetry.parseDependencies`.

      Type: translatePoetryProject :: AttrSet -> lambda

      Example:
        # translatePoetryProject (lib.importTOML ./pyproject.toml)
        { }  # TOML contents, structure omitted. See PEP-621 for more information on data members.
    */
    translatePoetryProject =
      pyproject:
      assert !(pyproject ? project);
      let
        inherit (pyproject.tool) poetry;
      in
      pyproject
      // {
        project = {
          inherit (poetry) name version description;
          authors = map translateAuthor poetry.authors;
          urls =
            optionalAttrs (poetry ? homepage) { Homepage = poetry.homepage; }
            // optionalAttrs (poetry ? repository) { Repository = poetry.repository; }
            // optionalAttrs (poetry ? documentation) { Documentation = poetry.documentation; };
        }
        // optionalAttrs (poetry ? license) { license.text = poetry.license; }
        // optionalAttrs (poetry ? maintainers) { maintainers = map translateAuthor poetry.maintainers; }
        // optionalAttrs (poetry ? readme) { inherit (poetry) readme; }
        // optionalAttrs (poetry ? keywords) { inherit (poetry) keywords; }
        // optionalAttrs (poetry ? classifiers) { inherit (poetry) classifiers; }
        // optionalAttrs (poetry ? scripts) { inherit (poetry) scripts; }
        // optionalAttrs (poetry ? plugins) { entry-points = poetry.plugins; };
      };

    /*
      Parse dependencies from pyproject.toml (Poetry edition).
      This function is analogous to `lib.pep621.parseDependencies`.

      Type: parseDependencies :: AttrSet -> AttrSet

      Example:
        # parseDependencies {
        #
        #   pyproject = (lib.importTOML ./pyproject.toml);
        # }
        {
          dependencies = [ ];  # List of parsed PEP-508 strings (lib.pep508.parseString)
          extras = {
            dev = [ ];  # List of parsed PEP-508 strings (lib.pep508.parseString)
          };
          build-systems = [ ];  # PEP-518 build-systems (List of parsed PEP-508 strings)
        }
    */
    parseDependencies = pyproject: {
      dependencies = map parseDependency (
        normalizeDependendenciesToList (pyproject.tool.poetry.dependencies or { })
      );
      extras = mapAttrs (
        _: group: map parseDependency (normalizeDependendenciesToList group.dependencies)
      ) pyproject.tool.poetry.group or { };
      build-systems = pep518.parseBuildSystems pyproject;

      # PEP-735 dependency groups
      groups = { };
    };

    /*
      Parse a version conditional.
      Supports additional non-standard operators `^` and `~` used by Poetry.

      Because some expressions desugar to multiple expressions parseVersionCond returns a list.

      Type: parseVersionCond :: string -> [ AttrSet ]
    */
    parseVersionCond =
      cond:
      (
        let
          m = match "^([~^])?([a-zA-Z0-9].+)$" cond;
          c = elemAt m 0;
          rest = elemAt m 1;
          # Pad version before parsing as it's _much_ easier to reason about
          # once they're the same length
          version = pep440.parseVersion (lib.versions.pad 3 rest);

          # Count the number of segments in the input to use an an index in ~ rewriting
          segments = length (filter (tok: typeOf tok == "string") (split "\\." rest));
        in
        if m == null then
          [ (pep440.parseVersionCond cond) ]
        # Desugar ~ into >= && <
        else if c == "~" then
          [
            {
              op = ">=";
              inherit version;
            }
            {
              op = "<";
              version = version // rec {
                release = lib.imap0 (
                  i: tok:
                  if i >= segments - 1 then
                    0
                  else if i == segments - 2 then
                    (tok + 1)
                  else
                    tok
                ) version.release;
                str = concatStringsSep "." (map toString release); # Overwrite with upper bounds
              };
            }
          ]
        # Desugar ^ into >= && <
        else if c == "^" then
          [
            {
              op = ">=";
              inherit version;
            }
            {
              op = "<";
              version = version // rec {
                release = rewriteCaretRhs version.release;
                str = concatStringsSep "." (map toString release); # Overwrite with upper bounds
              };
            }
          ]
        # Versions without operators are exact matches, add operator according to PEP-440
        else
          [
            {
              op = "==";
              inherit version;
            }
          ]
      );

    /*
      Parse a comma separated list version conditionals.
      Supports additional non-standard operators `^` and `~` used by Poetry.

      Type: parseVersionConds :: string -> [ AttrSet ]
    */
    parseVersionConds = s: concatLists (map self.parseVersionCond (splitComma s));
  }
)
