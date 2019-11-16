{ lib, stdenv }: python:

let

  # Like builtins.substring but with stop being offset instead of length
  substr = start: stop: s: builtins.substring start (stop - start) s;

  # Strip leading/trailing whitespace from string
  stripStr = s: lib.elemAt (builtins.split "^ *| *$" s) 2;

  findSubExpressionsFun = acc: c: (
    if c == "(" then (
      let
        posNew = acc.pos + 1;
        isOpen = acc.openP == 0;
        startPos = if isOpen then posNew else acc.startPos;
        exprs = if isOpen then acc.exprs else acc.exprs ++ [ (substr acc.exprPos (acc.pos - 1) acc.expr) ];
      in acc // {
        inherit exprs startPos;
        pos = posNew;
        openP = acc.openP + 1;
      }
    ) else if c == ")" then (
      let
        openP = acc.openP - 1;
        exprs = findSubExpressions (substr acc.startPos acc.pos acc.expr);
      in acc // {
        inherit openP;
        pos = acc.pos + 1;
        exprs = if openP == 0 then acc.exprs ++ [ exprs ] else acc.exprs;
        exprPos = if openP == 0 then acc.pos + 1 else acc.exprPos;
      }
    ) else acc // {pos = acc.pos + 1;}
  );

  # Make a tree out of expression groups (parens)
  findSubExpressions = expr: let
    acc = builtins.foldl' findSubExpressionsFun {
      exprs = [];
      expr = expr;
      pos = 0;
      openP = 0;
      exprPos = 0;
      startPos = 0;
    } (lib.stringToCharacters expr);
  in acc.exprs ++ [ (substr acc.exprPos acc.pos expr) ];

  parseExpressions = exprs: let
    splitCond = (s: builtins.map
    (x: if builtins.typeOf x == "list" then (builtins.elemAt x 0) else x)
    (builtins.split " (and|or) " s));

    mapfn = expr: (
      if (builtins.match "^ ?$" expr != null) then null  # Filter empty
      else if (builtins.elem expr [ "and" "or" ]) then {
        type = "bool";
        value = expr;
      }
      else {
        type = "expr";
        value = expr;
      });

      parsed = builtins.filter (x: x != null) (builtins.map mapfn (splitCond exprs));

  in if builtins.typeOf exprs == "string" then parsed else builtins.map parseExpressions exprs;

  # Transform individual expressions to structured expressions
  # This function also performs variable substitution, replacing environment markers with their explicit values
  transformExpressions = exprs: let
    variables = {
      os_name = "posix";  # TODO: Check other platforms
      sys_platform = (
        if stdenv.isLinux then "linux"
        else if stdenv.isDarwin then "darwin"
        else throw "Unsupported platform"
      );
      platform_machine = stdenv.platform.kernelArch;
      platform_python_implementation = "CPython";  # Only CPython supported for now
      platform_release = "";  # Field not reproducible
      platform_system = (
        if stdenv.isLinux then "Linux"
        else if stdenv.isDarwin then "Darwin"
        else throw "Unsupported platform"
      );
      platform_version = "";  # Field not reproducible
      python_version = python.passthru.pythonVersion;
      python_full_version = python.version;
      implementation_name = "cpython";  # Only cpython supported for now
      implementation_version = python.version;
      extra = "";
    };

    substituteVar = value: if builtins.hasAttr value variables then (builtins.toJSON variables."${value}") else value;

    processVar = value: builtins.foldl' (acc: v: v acc) value [
      stripStr
      substituteVar
    ];

  in if builtins.typeOf exprs == "set" then (
    if exprs.type == "expr" then (let
      mVal = ''[a-zA-Z0-9\'"_\. ]+'';
      mOp = "in|[!=<>]+";
      e = stripStr exprs.value;
      m = builtins.map stripStr (builtins.match ''^(${mVal}) *(${mOp}) *(${mVal})$'' e);
    in {
      type = "expr";
      value = {
        op = builtins.elemAt m 1;
        values = [
          (processVar (builtins.elemAt m 0))
          (processVar (builtins.elemAt m 2))
        ];
      };
    }) else exprs
  ) else builtins.map transformExpressions exprs;

  # Recursively eval all expressions
  evalExpressions = exprs: let
    unmarshal = v: (
      # TODO: Handle single quoted values
      if v == "True" then true
      else if v == "False" then false
      else builtins.fromJSON v
    );
    hasElem = needle: haystack: builtins.elem needle (builtins.filter (x: builtins.typeOf x == "string") (builtins.split " " haystack));
    # TODO: Implement all operators
    op = {
      "<=" = x: y: (unmarshal x) <= (unmarshal y);
      "<" = x: y: (unmarshal x) < (unmarshal y);
      "!=" = x: y: x != y;
      "==" = x: y: x == y;
      ">=" = x: y: (unmarshal x) >= (unmarshal y);
      ">" = x: y: (unmarshal x) > (unmarshal y);
      "~=" = null;
      "===" = null;
      "in" = x: y: let
        values = builtins.filter (x: builtins.typeOf x == "string") (builtins.split " " (unmarshal y));
      in builtins.elem (unmarshal x) values;
    };
  in if builtins.typeOf exprs == "set" then (
    if exprs.type == "expr" then (let
      expr = exprs;
      result = (op."${expr.value.op}") (builtins.elemAt expr.value.values 0) (builtins.elemAt expr.value.values 1);
      in {
        type = "value";
        value = result;
      }) else exprs
  ) else builtins.map evalExpressions exprs;

  # Now that we have performed an eval all that's left to do is to concat the graph into a single bool
  reduceExpressions = exprs: let
    cond = {
      "and" = x: y: x && y;
      "or" = x: y: x || y;
    };

    reduceExpressionsFun = acc: v: (
      if builtins.typeOf v == "set" then (
        if v.type == "value" then (
          acc // {
            value = cond."${acc.cond}" acc.value v.value;
          }
        ) else if v.type == "bool" then (
          acc // {
            cond = v.value;
          }
        ) else throw "Unsupported type"
      ) else if builtins.typeOf v == "list" then (
        builtins.foldl' reduceExpressionsFun acc v
      ) else throw "Unsupported type"
    );
  in (builtins.foldl' reduceExpressionsFun {
    value = true;
    cond = "and";
  } exprs).value;

in e: builtins.foldl' (acc: v: v acc) e [
  findSubExpressions
  parseExpressions
  transformExpressions
  evalExpressions
  reduceExpressions
]
