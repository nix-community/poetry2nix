{ lib, pep508, ... }:
let
  inherit (builtins)
    match
    head
    tail
    typeOf
    split
    filter
    foldl'
    readFile
    dirOf
    hasContext
    unsafeDiscardStringContext
    ;
  inherit (import ./lib.nix { inherit lib; }) stripStr;

  uncomment = l: head (match " *([^#]*).*" l);

in
lib.fix (self: {

  /*
    Parse dependencies from requirements.txt

    Type: parseRequirementsTxt :: AttrSet -> list

    Example:
    # parseRequirements ./requirements.txt
    [ { flags = []; requirement = {}; # Returned by pep508.parseString } ]
  */

  parseRequirementsTxt =
    # The contents of or path to requirements.txt
    requirements:
    let
      # Paths are either paths or strings with context.
      # Preferably we'd just use paths but because of
      #
      # $ ./. + requirements
      # "a string that refers to a store path cannot be appended to a path"
      #
      # We also need to support stringly paths...
      isPath = typeOf requirements == "path" || hasContext requirements;
      path' = if isPath then requirements else /. + unsafeDiscardStringContext requirements;
      root = dirOf path';

      # Requirements without comments and no empty strings
      requirements' = if isPath then readFile path' else requirements;
      lines' = filter (l: l != "") (
        map uncomment (filter (l: typeOf l == "string") (split "\n" requirements'))
      );
      # Fold line continuations
      inherit
        (
          (foldl'
            (
              acc: l':
              let
                m = match "(.+) *\\\\" l';
                continue = m != null;
                l = stripStr (if continue then (head m) else l');
              in
              if continue then
                {
                  line = acc.line ++ [ l ];
                  inherit (acc) lines;
                }
              else
                {
                  line = [ ];
                  lines = acc.lines ++ [ (acc.line ++ [ l ]) ];
                }
            )
            {
              lines = [ ];
              line = [ ];
            }
            lines'
          )
        )
        lines
        ;

    in
    foldl' (
      acc: l:
      let
        m = match "-(c|r) (.+)" (head l);
      in
      acc
      ++ (
        # Common case, parse string
        if m == null then
          [
            {
              requirement = pep508.parseString (head l);
              flags = tail l;
            }
          ]

        # Don't support constraint files
        else if (head m) == "c" then
          throw "Unsupported flag: -c"

        # Recursive requirements.txt
        else
          (self.parseRequirementsTxt (
            if root == null then
              throw "When importing recursive requirements.txt requirements needs to be passed as a path"
            else
              root + "/${head (tail m)}"
          ))
      )
    ) [ ] lines;
})
