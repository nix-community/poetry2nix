{ lib, ... }:
let
  inherit (builtins) split filter match length elemAt head foldl' fromJSON typeOf;
  inherit (lib) fix isString toInt toLower sublist;
  inherit (import ./util.nix { inherit lib; }) splitComma;

  filterNull = filter (x: x != null);
  filterEmpty = filter (x: length x > 0);
  filterEmptyStr = filter (s: s != "");

  # A version of lib.toInt that supports leading zeroes
  toIntRelease = s:
    let
      n = fromJSON (head (match "0?([[:digit:]]+)" s));
    in
    assert typeOf n == "int"; n;

  # Return a list elem at index with a default value if it doesn't exist
  optionalElem = list: idx: default: if length list >= idx + 1 then elemAt list idx else default;

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

  # Parse a release (pre/post/whatever) attrset from split tokens
  parseReleaseSuffix = patterns: tokens:
    let
      matches = map
        (x:
          let
            type = toLower (elemAt x 0);
            value = elemAt x 1;
          in
          {
            type = normalizedReleaseTypes.${type} or type;
            value = if value != "" then toInt value else 0;
          })
        (filterNull (map (match "[0-9]*(${patterns})([0-9]*)") tokens));
    in
    assert length matches <= 1; optionalElem matches 0 null;

  parsePre = parseReleaseSuffix "a|b|c|rc|alpha|beta|pre|preview";
  parsePost = parseReleaseSuffix "post|rev|r|\-";
  parseDev = parseReleaseSuffix "dev";
  parseLocal = parseReleaseSuffix "\\+";

  # Compare the release fields from the parsed version
  compareRelease = offset: ra: rb:
    let
      x = elemAt ra offset;
      y = elemAt rb offset;
    in
    if length ra == offset || length rb == offset then 0 else
    (
      if x == "*" || y == "*" then 0 # Wildcards are always considered equal
      else
        (
          if x > y then 1
          else if x < y then -1
          else compareRelease (offset + 1) ra rb
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
  compareVersionModifier = x: y: assert x != null && y != null; let
    prioX = modifierPriority.${x.type};
    prioY = modifierPriority.${y.type};
  in
  if prioX == prioY then
    (
      if x.value == y.value then 0
      else if x.value > y.value then 1
      else -1
    )
  else if prioX > prioY then 1
  else 0;

in
fix (self: {

  /* Parse a version according to PEP-440.

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
  parseVersion = version:
    let
      tokens = filter isString (split "\\." version);
    in
    {
      # Return epoch defaulting to 0
      epoch = toInt (optionalElem (map head (filterNull (map (match "[0-9]+!([0-9]+)") tokens))) 0 "0");
      release = map (t: (x: if x == "*" then x else toIntRelease x) (head t)) (filterEmpty (map (t: filterEmptyStr (match "([\\*0-9]*).*" t)) tokens));
      pre = parsePre tokens;
      post = parsePost tokens;
      dev = parseDev tokens;
      local = parseLocal tokens;
    };

  /* Parse a version conditional.

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
  parseVersionCond = cond: (
    let
      m = match " *([=><!~^]*) *(.+)" cond;
      mAt = elemAt m;
    in
    {
      op = mAt 0;
      version = self.parseVersion (mAt 1);
    }
  );

  /* Parse a list of version conditionals separated by commas.

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
  parseVersionConds = conds: map self.parseVersionCond (splitComma conds);

  /* Compare two versions as parsed by `parseVersion` according to PEP-440.

     Returns:
       - -1 for less than
       - 0 for equality
       - 1 for greater than

     Type: compareVersions :: AttrSet -> AttrSet -> int

     Example:
       # compareVersions (parseVersion "3.0.0") (parseVersion "3.0.0")
       0
  */
  compareVersions = a: b: foldl' (acc: comp: if acc != 0 then acc else comp) 0 [
    # mixing dev/pre/post like:
    # 1.0b2.post345.dev456
    # 1.0b2.post345
    # is valid and we need to consider them all.

    # Compare release field
    (compareRelease 0 a.release b.release)

    # Compare pre release
    (
      if a.pre != null && b.pre != null then compareVersionModifier a.pre b.pre
      else if a.pre != null then -1
      else if b.pre != null then 1
      else 0
    )

    # Compare dev release
    (
      if a.dev != null && b.dev != null then compareVersionModifier a.dev b.dev
      else if a.dev != null then -1
      else if b.dev != null then 1
      else 0
    )

    # Compare post release
    (
      if a.post != null && b.post != null then compareVersionModifier a.post b.post
      else if a.post != null then 1
      else if b.post != null then -1
      else 0
    )

    # Compare epoch
    (
      if a.epoch == b.epoch then 0
      else if a.epoch > b.epoch then 1
      else -1
    )

    # Compare local
    (
      if a.local != null && b.local != null then compareVersionModifier a.local b.local
      else if b.local != null then -1
      else 0
    )
  ];

  /* Map comparison operators as strings to a comparator function.

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
    "~=" = a: b: (
      # Local version identifiers are NOT permitted in this version specifier.
      assert a.local == null && b.local == null;
      self.comparators.">=" a b && self.comparators."==" a (b // {
        release = sublist 0 ((length b.release) - 1) b.release;
        # If a pre-release, post-release or developmental release is named in a compatible release clause as V.N.suffix, then the suffix is ignored when determining the required prefix match.
        pre = null;
        post = null;
        dev = null;
      })
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
