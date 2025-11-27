{ lib, ... }:
let
  inherit (builtins)
    split
    filter
    match
    length
    elemAt
    head
    fromJSON
    typeOf
    compareVersions
    ;
  inherit (lib)
    fix
    isString
    toInt
    sublist
    findFirst
    ;
  inherit (import ./lib.nix { inherit lib; }) splitComma;

  # A version of lib.toInt that supports leading zeroes
  toIntRelease =
    let
      matchDigit = match "0?([[:digit:]]+)";
    in
    s:
    if s == "*" then
      s
    else
      let
        n = fromJSON (head (matchDigit s));
      in
      assert typeOf n == "int";
      n;

  emptyVersion = {
    dev = null;
    epoch = 0;
    local = null;
    post = null;
    pre = null;
    release = [ ];
    str = "";
  };

  # We consider some words to be alternate spellings of other words and
  # in those cases we want to normalize the spellings to our preferred
  # spelling.
  normalizedReleaseTypes = {
    alpha = "a";
    beta = "b";
    c = "rc";
    pre = "rc";
    preview = "rc";
    rev = "post";
    r = "post";
    "-" = "post";
  };
  normalizedReleaseType = type: normalizedReleaseTypes.${type} or type;

  # Compare the release fields from the parsed version
  compareRelease =
    offset: ra: rb:
    if length ra == offset || length rb == offset then
      0
    else
      (
        let
          x = elemAt ra offset;
          y = elemAt rb offset;
        in
        if x == "*" || y == "*" then
          0 # Wildcards are always considered equal
        else
          (
            if x > y then
              1
            else if x < y then
              -1
            else
              compareRelease (offset + 1) ra rb
          )
      );

  # Normalized modifier to it's priority (in case we are comparing an alpha to a beta or similar)
  modifierPriority = {
    dev = -1;
    a = 0;
    b = 1;
    rc = 2;
    post = 3;
  };

  # Compare dev/pre/post/local release modifiers
  compareVersionModifier =
    x: y:
    assert x != null && y != null;
    let
      prioX = modifierPriority.${x.type};
      prioY = modifierPriority.${y.type};
    in
    if prioX == prioY then
      (
        if x.value == y.value then
          0
        else if x.value > y.value then
          1
        else
          -1
      )
    else if prioX > prioY then
      1
    else
      0;

in
fix (self: {

  /*
    Parse a version according to PEP-440.

    Type: parseVersion :: string -> AttrSet

    Example:
      # parseVersion "3.0.0rc1"
      {
        dev = null;
        epoch = 0;
        local = null;
        post = null;
        pre = {
          type = "rc";
          value = 1;
        };
        release = [ 3 0 0 ];
      }
  */
  parseVersion =
    version:
    if version == "" then
      emptyVersion
    else
      let
        # Split input into (_, epoch, release, modifiers)
        tokens = match "(([0-9]+)!)?([^-\+a-zA-Z]+)(.*)" version;
        tokenAt = elemAt tokens;

        # Segments
        epochSegment = tokenAt 1;
        releaseSegment = tokenAt 2;
        modifierLocalSegment = tokenAt 3;

        # Split modifier/local segment
        mLocal = match "([^\\+]*)\\+?(.*)" modifierLocalSegment;
        mLocalAt = elemAt mLocal;
        modifiersSegment = mLocalAt 0;
        local = mLocalAt 1;

        # Parse each post345/dev1 string into attrset
        modifiers = map (
          mod:
          let
            # Split post345 into ["post" "345"]
            m = match "-?([^0-9]+)([0-9]+)" mod;
          in
          if m == null then
            throw "PEP-440 modifier segment invalid: ${mod}"
          # assert m != null;
          else
            {
              type = normalizedReleaseType (elemAt m 0);
              value = toIntRelease (elemAt m 1);
            }
        ) (filter (s: isString s && s != "") (split "\\." modifiersSegment));

      in
      if tokens == null || mLocal == null then
        throw "Invalid PEP-440 version: ${version}"
      else
        {
          # Return epoch defaulting to 0
          epoch = if epochSegment != null then toInt epochSegment else 0;

          # Parse release segments delimited by dots into list of ints
          release = map toIntRelease (filter (s: isString s && s != "") (split "\\." releaseSegment));

          # Find modifiers in modifiers list
          pre = findFirst (mod: mod.type == "rc" || mod.type == "b" || mod.type == "a") null modifiers;
          post = findFirst (mod: mod.type == "post") null modifiers;
          dev = findFirst (mod: mod.type == "dev") null modifiers;

          # Local releases needs to be treated specially.
          # The value isn't just a straight up number, but an arbitrary string.
          local = if local != "" then local else null;

          # Return the input verbatim for lexicographical comparisons such as those
          # done for platform_release which is parsed as PEP-440 when compliant,
          # but are compare lexicographically when the version string is non-compliant.
          str = version;
        };

  /*
    Parse a version conditional.

    Type: parseVersionCond :: string -> AttrSet

    Example:
      # parseVersionCond ">=3.0.0rc1"
      {
        op = ">=";
        version = {
          dev = null;
          epoch = 0;
          local = null;
          post = null;
          pre = {
            type = "rc";
            value = 1;
          };
          release = [ 3 0 0 ];
        };
      }
  */
  parseVersionCond =
    cond:
    (
      let
        m = match " *([=><!~^]*) *(.+)" cond;
      in
      assert m != null;
      {
        op = elemAt m 0;
        version = self.parseVersion (elemAt m 1);
      }
    );

  /*
    Parse a list of version conditionals separated by commas.

    Type: parseVersionConds :: string -> [AttrSet]

    Example:
      # parseVersionConds ">=3.0.0rc1,<=4.0"
      [
        {
          op = ">=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = {
              type = "rc";
              value = 1;
            };
            release = [ 3 0 0 ];
          };
        }
        {
          op = "<=";
          version = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ 4 0 ];
          };
        }
      ]
  */
  parseVersionConds =
    conds:
    let
      # If the conditions are surrounded by parens strip them away
      parenM = match "\\((.+)\\)" conds;
    in
    map self.parseVersionCond (splitComma (if parenM != null then head parenM else conds));

  /*
    Compare two versions as parsed by `parseVersion` according to PEP-440.

    Returns:
      - -1 for less than
      - 0 for equality
      - 1 for greater than

    Type: compareVersions :: AttrSet -> AttrSet -> int

    Example:
      # compareVersions (parseVersion "3.0.0") (parseVersion "3.0.0")
      0
  */
  compareVersions =
    a: b:
    let
      releaseComp = compareRelease 0 a.release b.release;
      preComp = compareVersionModifier a.pre b.pre;
      devComp = compareVersionModifier a.dev b.dev;
      postComp = compareVersionModifier a.post b.post;
      localComp = compareVersions a.local b.local;
    in
    if a.epoch > b.epoch then
      1
    else if a.epoch < b.epoch then
      -1

    # Compare release field
    else if releaseComp != 0 then
      releaseComp

    # Compare pre release
    else if a.pre != null && b.pre != null && preComp != 0 then
      preComp
    else if a.pre != null && b.pre == null then
      -1
    else if b.pre != null && a.pre == null then
      1

    # Compare dev release
    else if a.dev != null && b.dev != null && devComp != 0 then
      devComp
    else if a.dev != null && b.dev == null then
      -1
    else if b.dev != null && a.dev == null then
      1

    # Compare post release
    else if a.post != null && b.post != null && postComp != 0 then
      postComp
    else if a.post != null && b.post == null then
      1
    else if b.post != null && a.post == null then
      -1

    # Compare local
    # HACK: Local are arbitrary strings.
    # We do a best estimate by comparing local as versions using builtins.compareVersions.
    # This is strictly not correct but it's better than no handling..
    else if a.local != null && b.local != null && localComp != 0 then
      localComp
    else if a.local != null && b.local == null then
      1
    else if b.local != null && a.local == null then
      -1

    # Equal
    else
      0;

  /*
    Map comparison operators as strings to a comparator function.

    Attributes:
      - [Compatible release clause](https://peps.python.org/pep-0440/#compatible-release): `~=`
      - [Version matching clause](https://peps.python.org/pep-0440/#version-matching): `==`
      - [Version exclusion clause](https://peps.python.org/pep-0440/#version-exclusion): `!=`
      - [Inclusive ordered comparison clause](https://peps.python.org/pep-0440/#inclusive-ordered-comparison): `<=`, `>=`
      - [Exclusive ordered comparison clause](https://peps.python.org/pep-0440/#exclusive-ordered-comparison): `<`, `>`
      - [Arbitrary equality clause](https://peps.python.org/pep-0440/#arbitrary-equality): `===`

    Type: operators.${operator} :: AttrSet -> AttrSet -> bool

    Example:
      # comparators."==" (parseVersion "3.0.0") (parseVersion "3.0.0")
      true
  */
  comparators = {
    "~=" =
      let
        gte = self.comparators.">=";
        eq = self.comparators."==";
      in
      a: b:
      (
        # Local version identifiers are NOT permitted in this version specifier.
        assert a.local == null && b.local == null;
        gte a b
        && eq a (
          b
          // {
            release = sublist 0 ((length b.release) - 1) b.release;
            # If a pre-release, post-release or developmental release is named in a compatible release clause as V.N.suffix, then the suffix is ignored when determining the required prefix match.
            pre = null;
            post = null;
            dev = null;
          }
        )
      );
    "==" = a: b: self.compareVersions a b == 0;
    "!=" = a: b: self.compareVersions a b != 0;
    "<=" = a: b: self.compareVersions a b <= 0;
    ">=" = a: b: self.compareVersions a b >= 0;
    "<" = a: b: self.compareVersions a b < 0;
    ">" = a: b: self.compareVersions a b > 0;
    "===" = throw "Arbitrary equality clause not supported";
    "" = _a: _b: true;
  };

})
