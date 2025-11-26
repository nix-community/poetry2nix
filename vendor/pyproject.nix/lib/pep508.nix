{
  lib,
  pep508,
  pep440,
  pep599,
  pypa,
  ...
}:

let
  inherit (builtins)
    match
    elemAt
    foldl'
    substring
    typeOf
    fromJSON
    toJSON
    isString
    head
    mapAttrs
    elem
    length
    isList
    any
    isAttrs
    tryEval
    deepSeq
    splitVersion
    concatStringsSep
    tail
    ;
  inherit (lib)
    stringToCharacters
    sublist
    hasInfix
    take
    toInt
    ;
  inherit (import ./lib.nix { inherit lib; }) splitComma stripStr;

  # Marker fields + their parsers
  markerFields =
    let
      default = value: {
        type = typeOf value;
        inherit value;
      };
      version = value: {
        type = "version";
        value = pep440.parseVersion value;
      };

      emptyPlatformRelease = {
        type = "platform_release";
        value = "";
      };

      platform_release =
        value:
        if value == "" then
          emptyPlatformRelease
        else
          let
            parsed' = pep440.parseVersion value;
            eval' = tryEval (deepSeq parsed' parsed');
          in
          {
            type = "platform_release";
            value = if eval'.success then eval'.value else value;
          };
    in
    {
      "implementation_name" = default;
      "implementation_version" = version;
      "os_name" = default;
      "platform_machine" = default;
      "platform_python_implementation" = default;
      "platform_release" = platform_release;
      "platform_system" = default;
      "platform_version" = default;
      "python_full_version" = version;
      "python_version" = version;
      "sys_platform" = default;
      "extra" =
        value:
        assert isList value || isString value;
        {
          type = "extra";
          inherit value;
        };
    };

  # Comparators for simple equality
  # For versions see pep440.comparators
  comparators = {
    "==" = a: b: a == b;
    "!=" = a: b: a != b;
    "<=" = a: b: a <= b;
    ">=" = a: b: a >= b;
    "<" = a: b: a < b;
    ">" = a: b: a > b;
    "===" = a: b: a == b;
  };

  # Special case comparators for the `extra` environment field
  extraComparators = {
    # Check for member in list if list, otherwise simply compare.
    "==" = extras: extra: if typeOf extras == "list" then elem extra extras else extras == extra;
    "!=" = extras: extra: if typeOf extras == "list" then !(elem extra extras) else extras != extra;
  };

  # Platform_release parsing is more complicated than other fields.
  #
  # If both lhs and rhs were correctly parsed as PEP-440 versions run regular version comparison,
  # otherwise compare lexicographically
  #
  # See:
  # - https://github.com/pypa/packaging/issues/774
  # - https://github.com/astral-sh/uv/issues/3917#issuecomment-2141754917
  platformReleaseComparators = {
    "==" =
      a: b: if isAttrs a && isAttrs b then pep440.comparators."==" a b else (a.str or a) == (b.str or b);
    "!=" =
      a: b: if isAttrs a && isAttrs b then pep440.comparators."!=" a b else (a.str or a) != (b.str or b);
    "<=" =
      a: b: if isAttrs a && isAttrs b then pep440.comparators."<=" a b else (a.str or a) <= (b.str or b);
    ">=" =
      a: b: if isAttrs a && isAttrs b then pep440.comparators.">=" a b else (a.str or a) >= (b.str or b);
    "<" =
      a: b: if isAttrs a && isAttrs b then pep440.comparators."<" a b else (a.str or a) < (b.str or b);

    ">" =
      a: b: if isAttrs a && isAttrs b then pep440.comparators.">" a b else (a.str or a) > (b.str or b);
    "===" = a: b: a == b;
  };

  boolOps = {
    "and" = x: y: x && y;
    "or" = x: y: x || y;
    "in" = x: y: hasInfix x y;
    "not in" = x: y: !(hasInfix x y);
  };

  primitives = [
    "int"
    "float"
    "string"
    "bool"
  ];

  # Copied from nixpkgs lib.findFirstIndex internals to save on a little bit of environment allocations.
  resultIndex' =
    pred:
    foldl' (
      index: el:
      if index < 0 then
        # No match yet before the current index, we need to check the element
        if pred el then
          # We have a match! Turn it into the actual index to prevent future iterations from modifying it
          -index - 1
        else
          # Still no match, update the index to the next element (we're counting down, so minus one)
          index - 1
      else
        # There's already a match, propagate the index without evaluating anything
        index
    ) (-1);

  inherit (pep508) parseMarkers evalMarkers;

in
{

  /*
    Parse PEP 508 markers into an AST.

    Type: parseMarkers :: string -> AttrSet

    Example:
      # parseMarkers "(os_name=='a' or os_name=='b') and os_name=='c'"
      {
        lhs = {
          lhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "a";
            };
            type = "compare";
          };
          op = "or";
          rhs = {
            lhs = {
              type = "variable";
              value = "os_name";
            };
            op = "==";
            rhs = {
              type = "string";
              value = "b";
            };
            type = "compare";
          };
          type = "boolOp";
        };
        op = "and";
        rhs = {
          lhs = {
            type = "variable";
            value = "os_name";
          };
          op = "==";
          rhs = {
            type = "string";
            value = "c";
          };
          type = "compare";
        };
        type = "boolOp";
      }
  */
  parseMarkers =
    let
      opChars = [
        "="
        ">"
        "<"
        "!"
        "~"
        "^"
      ];

      # State exit conditions
      emptyOrOp = _pos: c: c == " " || c == "(" || c == ")" || elem c opChars;
      nonOp = _pos: c: !elem c opChars;
      anyCond = _pos: _c: true;
      # Use look-behind to assess whether a string was closed
      stringCond' =
        char: chars: startPos: pos: _c:
        pos - 1 != startPos && (elemAt chars (pos - 1)) == char;
      singleStringCond' = stringCond' "'";
      doubleStringCond' = stringCond' "\"";

    in
    input:
    if input == "" then
      [ ]
    else
      let
        chars = stringToCharacters input;
        cmax = (length chars) - 1;
        last = elemAt chars cmax;
        singleStringCond = singleStringCond' chars;
        doubleStringCond = doubleStringCond' chars;

        # Find tokens in character stream
        tokens' =
          foldl'
            (acc: c: rec {
              # Current position
              pos = acc.pos + 1;

              # Set start position of token to current position if exit condition matches
              start =
                if acc.cond pos c then
                  (if c == " " then -1 else pos) # If character is whitespace keep seeking
                else
                  acc.start; # Else propagate start position

              # Assign new exit condition on state change
              cond =
                if start == pos || start == -1 then
                  (
                    if c == " " || c == "(" || c == ")" then
                      anyCond
                    else if c == "\"" then
                      (doubleStringCond pos)
                    else if c == "'" then
                      (singleStringCond pos)
                    else if elem c opChars then
                      nonOp
                    else
                      emptyOrOp
                  )
                else
                  acc.cond;

              tokens =
                # Reached end of token
                if acc.start != -1 && start != acc.start then
                  acc.tokens ++ [ (substring acc.start (pos - acc.start) input) ]
                # Reached end of input
                else if pos == cmax && acc.start != -1 then
                  acc.tokens ++ [ (substring acc.start (cmax + 1 - acc.start) input) ]
                else
                  acc.tokens;

            })
            {
              pos = -1; # Parser position
              start = -1; # Start position for current token (-1 indicates searching through whitespace)
              cond = anyCond; # Function condition ending current parser state
              tokens = [ ]; # List of discovered tokens as strings
            }
            chars;

        # Special case: Single character tail token
        tokens =
          if tokens'.start == cmax && last != " " then tokens'.tokens ++ [ last ] else tokens'.tokens;

        # Group tokens according to paren expression groups
        ltokens = length tokens;
        groupTokens =
          stack: i:
          if i == ltokens then
            stack
          else
            let
              token = elemAt tokens i;
            in
            # New group, initialize a new stack
            if token == "(" then
              (
                let
                  group' = groupTokens [ ] (i + 1);
                in
                groupTokens (stack ++ [ (elemAt group' 0) ]) (elemAt group' 1)
              )
            # Closing group, return stack
            else if token == ")" then
              # Return a tuple of stack and next so the "(" branch above can know where the list is closed
              [
                stack
                (i + 1)
              ]
            # Append all other token types to stack.
            else
              groupTokens (stack ++ [ token ]) (i + 1);

        # The grouping routine is a tad slow and uses recursion.
        # We can completely avoid it if the input doesn't contain any grouped subexpressions.
        groupedTokens = if any (token: token == "(") tokens then groupTokens [ ] 0 else tokens;

        # Reduce values into AST
        reduceValue =
          lhs': value:
          if isList value then
            (
              if length value == 1 then
                reduceValue lhs' (head value)
              else
                (
                  let
                    # Find different kinds of infix operators & comparisons
                    orIdx = resultIndex' (token: token == "or") value;
                    andIdx = resultIndex' (token: token == "and") value;
                    compIdx = resultIndex' (token: comparators ? ${token}) value;
                    inIdx = resultIndex' (token: token == "in") value;
                    notIdx = # Take possible negation into account
                      if inIdx > 0 && elemAt value (inIdx - 1) == "not" then inIdx - 1 else -1;
                  in
                  # Value has a logical or (takes precedence over and)
                  if orIdx > 0 then
                    {
                      type = "boolOp";
                      lhs = reduceValue lhs' (sublist 0 orIdx value);
                      op = elemAt value orIdx;
                      rhs = reduceValue lhs' (sublist (orIdx + 1) (length value - 1) value);
                    }
                  # Value has a logical and
                  else if andIdx > 0 then
                    {
                      type = "boolOp";
                      lhs = reduceValue lhs' (sublist 0 andIdx value);
                      op = elemAt value andIdx;
                      rhs = reduceValue lhs' (sublist (andIdx + 1) (length value - 1) value);
                    }
                  # Value has a comparison (==, etc) operator
                  else if compIdx >= 0 then
                    rec {
                      type = "compare";
                      lhs = reduceValue lhs' (sublist 0 compIdx value);
                      op = elemAt value compIdx;
                      rhs = reduceValue lhs (sublist (compIdx + 1) (length value - 1) value);
                    }
                  else if notIdx > 0 then
                    rec {
                      type = "boolOp";
                      lhs = reduceValue lhs' (sublist 0 notIdx value);
                      op = "not in";
                      rhs = reduceValue lhs (sublist (inIdx + 1) (length value - 1) value);
                    }
                  else if inIdx > 0 then
                    rec {
                      type = "boolOp";
                      lhs = reduceValue lhs' (sublist 0 inIdx value);
                      op = "in";
                      rhs = reduceValue lhs (sublist (inIdx + 1) (length value - 1) value);
                    }
                  else
                    throw "Unhandled state for input value: ${toJSON value}"
                )
            )
          else if markerFields ? ${value} then
            {
              type = "variable";
              inherit value;
            }
          else
            (
              let
                singleTicked = match "^'(.+)'$" value;
                value' = fromJSON (if singleTicked != null then "\"${head singleTicked}\"" else value);
              in
              if lhs' != { } && lhs'.type == "variable" then
                markerFields.${lhs'.value} value'
              else
                {
                  type = typeOf value';
                  value = value';
                }
            );
      in
      reduceValue { } groupedTokens;

  /*
    Parse a PEP-508 dependency string.

    Type: parseString :: string -> AttrSet

    Example:
      # parseString "cachecontrol[filecache]>=0.13.0"
      {
        conditions = [
          {
            op = ">=";
            version = {
              dev = null;
              epoch = 0;
              local = null;
              post = null;
              pre = null;
              release = [ 0 13 0 ];
            };
          }
        ];
        markers = null;
        name = "cachecontrol";
        extras = [ "filecache" ];
        url = null;
      }
  */
  parseString =
    input:
    let
      # Split the input into it's distinct parts: The package segment, URL and environment markers
      tokens =
        let
          # Input has both @ and ; separators (both URL and markers)
          # "name [fred,bar] @ http://foo.com ; python_version=='2.7'"
          m1 = match "^(.+)@(.+);(.+)$" input;

          # Input has ; separator (markers)
          # "name [fred,bar] ; python_version=='2.7'"
          m2 = match "^(.+);(.+)$" input;

          # Input has @ separator (URL)
          # "name [fred,bar] @ http://foo.com"
          m3 = match "^(.+)@(.+)$" input;

        in
        if m1 != null then
          {
            packageSegment = elemAt m1 0;
            url = stripStr (elemAt m1 1);
            markerSegment = elemAt m1 2;
          }
        else if m2 != null then
          {
            packageSegment = elemAt m2 0;
            url = null;
            markerSegment = elemAt m2 1;
          }
        else if m3 != null then
          {
            packageSegment = elemAt m3 0;
            url = stripStr (elemAt m3 1);
            markerSegment = null;
          }
        else
          (
            if match ".+\/.+" input != null then
              # Input is a bare URL
              {
                packageSegment = null;
                url = input;
                markerSegment = null;
              }
            else
              # Input is a package name
              {
                packageSegment = input;
                url = null;
                markerSegment = null;
              }
          );

      # Extract metadata from the package segment
      package =
        let
          # Package has either both extras and version constraints or just extras
          # "name [fred,bar]>=3.10"
          # "name [fred,bar]"
          m1 = match "(.+)\\[(.*)](.*)" tokens.packageSegment;

          # Package has either version constraints or is bare
          # "name>=3.2"
          # "name"
          m2 = match "([a-zA-Z0-9_\\.-]+)(.*)" tokens.packageSegment;

          # The version conditions as a list of strings
          conditions = pep440.parseVersionConds (if m1 != null then elemAt m1 2 else elemAt m2 1);

          # Extras as a list of strings
          #
          # Based on PEP-508 alone it's not clear whether extras should be normalized or not.
          # From discussion in https://github.com/pypa/packaging-problems/issues/230
          # missing normalization seems like an oversight.
          extras = if m1 != null then map pypa.normalizePackageName (splitComma (elemAt m1 1)) else [ ];

        in
        if tokens.packageSegment == null then
          {
            name = null;
            conditions = [ ];
            extras = [ ];
          }
        else
          # Assert that either regex matched
          assert m1 != null || m2 != null;
          {
            # Based on PEP-508 alone it's not clear whether names should be normalized or not.
            # From discussion in https://github.com/pypa/packaging-problems/issues/230
            # this seems like an oversight and we _should_ actually canonicalize names at parse time.
            name = pypa.normalizePackageName (stripStr (if m1 != null then elemAt m1 0 else elemAt m2 0));
            inherit extras conditions;
          };

    in
    {
      name =
        if package.name != null then
          package.name
        # Infer name from URL if no name was specified explicitly
        else if tokens.url != null then
          (
            let
              inherit (tokens) url;
              mEggFragment = match ".+#egg=(.+)" url;
            in
            if mEggFragment != null then elemAt mEggFragment 0 else null
          )
        else
          null;
      inherit (package) conditions extras;
      inherit (tokens) url;
      markers = if tokens.markerSegment == null then null else parseMarkers tokens.markerSegment;
    };

  /*
    Create an attrset of platform variables.
    As described in https://peps.python.org/pep-0508/#environment-markers.

    Type: mkEnviron :: derivation -> AttrSet

    Example:
      # mkEnviron pkgs.python3
      {
        implementation_name = {
          type = "string";
          value = "cpython";
        };
        implementation_version = {
          type = "version";
          value = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ 3 10 12 ];
          };
        };
        os_name = {
          type = "string";
          value = "posix";
        };
        platform_machine = {
          type = "string";
          value = "x86_64";
        };
        platform_python_implementation = {
          type = "string";
          value = "CPython";
        };
        # platform_release maps to platform.release() which returns
        # the running kernel version on Linux.
        # Because this field is not reproducible it's left empty.
        platform_release = {
          type = "string";
          value = "";
        };
        platform_system = {
          type = "string";
          value = "Linux";
        };
        # platform_version maps to platform.version() which also returns
        # the running kernel version on Linux.
        # Because this field is not reproducible it's left empty.
        platform_version = {
          type = "version";
          value = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ ];
          };
        };
        python_full_version = {
          type = "version";
          value = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ 3 10 12 ];
          };
        };
        python_version = {
          type = "version";
          value = {
            dev = null;
            epoch = 0;
            local = null;
            post = null;
            pre = null;
            release = [ 3 10 ];
          };
        };
        sys_platform = {
          type = "string";
          value = "linux";
        };
      }
  */
  mkEnviron =
    python:
    let
      inherit (python) stdenv;
      inherit (stdenv) targetPlatform;
      inherit (targetPlatform)
        isLinux
        isDarwin
        isFreeBSD
        isAarch64
        isx86_64
        ;
      impl = python.passthru.implementation;
    in
    mapAttrs (name: markerFields.${name}) {
      os_name = if python.pname == "jython" then "java" else "posix";
      sys_platform =
        if isLinux then
          "linux"
        else if isDarwin then
          "darwin"
        else if isFreeBSD then
          "freebsd${head (splitVersion stdenv.cc.libc.version)}"
        else
          throw "Unsupported platform";
      platform_machine =
        if isDarwin then
          targetPlatform.darwinArch
        else if isLinux then
          pep599.manyLinuxTargetMachines.${targetPlatform.parsed.cpu.name} or targetPlatform.parsed.cpu.name
        else if isFreeBSD then
          (
            if isx86_64 then
              "amd64"
            else if isAarch64 then
              "arm64"
            else
              throw "Unhandled FreeBSD architecture"
          )
        else
          throw "Unsupported platform";
      platform_python_implementation =
        if impl == "cpython" then
          "CPython"
        else if impl == "pypy" then
          "PyPy"
        else
          throw "Unsupported implementation ${impl}";
      # We have no reliable value to set platform_release to.
      # In theory this could be set to linuxHeaders.version on Linux, but that's
      # not correct
      platform_release =
        if isLinux then
          stdenv.cc.libc.linuxHeaders.version
        else if isDarwin then
          (
            let
              tokens = splitVersion targetPlatform.darwinSdkVersion;
            in
            concatStringsSep "." ([ (toString ((toInt (head tokens)) + 9)) ] ++ tail tokens)
          )
        else if isFreeBSD then
          "${concatStringsSep "." (take 2 (splitVersion stdenv.cc.libc.version))}-RELEASE"
        else
          throw "Unsupported platform";
      platform_system =
        if isLinux then
          "Linux"
        else if isDarwin then
          "Darwin"
        else if isFreeBSD then
          "FreeBSD"
        else
          throw "Unsupported platform";
      platform_version = ""; # Field not reproducible
      python_version = python.passthru.pythonVersion;
      # Nixpkgs lacks an equivalent of python_full_version.
      # This isn't a problem on CPython where we can use python.version to get the full version,
      # but on pypy we don't know which language patch version of Python the interpreter is for.
      python_full_version =
        if lib.hasPrefix python.passthru.pythonVersion python.version then
          python.version
        else
          python.passthru.pythonVersion;
      implementation_name = python.passthru.implementation;
      implementation_version = python.version;
    };

  /*
    Update one or more keys in an environment created by mkEnviron.

    Example:
      # setEnviron (mkEnviron pkgs.python3) { platform_release = "5.10.65";  }
  */
  setEnviron = environ: updates: environ // mapAttrs (name: markerFields.${name}) updates;

  /*
    Evaluate an environment as returned by `mkEnviron` against markers as returend by `parseMarkers`.

    Type: evalMarkers :: AttrSet -> AttrSet -> bool

    Example:
      # evalMarkers (mkEnviron pkgs.python3) (parseMarkers "python_version < \"3.11\"")
      true
  */
  evalMarkers =
    environ: value:
    (
      if value.type == "compare" then
        (
          (
            # platform_release is being compared as foo
            if value.lhs.type == "variable" && value.lhs.value == "platform_release" then
              platformReleaseComparators.${value.op}
            # Version comparison
            else if value.lhs.type == "version" || value.rhs.type == "version" then
              pep440.comparators.${value.op}
            # `Extra` environment marker comparison requires special casing because it's equality checks can
            # == can be considered a `"key" in set` comparison when multiple extras are activated for a dependency.
            # If we didn't treat it this way the check would become quadratic as `evalMarkers` only could check one extra at a time.
            else if value.lhs.type == "variable" || value.lhs.value == "extra" then
              extraComparators.${value.op}
            # Simple equality
            else
              comparators.${value.op}
          )
          (evalMarkers environ value.lhs)
          (evalMarkers environ value.rhs)
        )
      else if value.type == "boolOp" then
        boolOps.${value.op} (evalMarkers environ value.lhs) (evalMarkers environ value.rhs)
      else if value.type == "variable" then
        (evalMarkers environ environ.${value.value})
      else if value.type == "version" || value.type == "extra" || value.type == "platform_release" then
        value.value
      else if elem value.type primitives then
        value.value
      else
        throw "Unknown type '${value.type}'"
    );

}
