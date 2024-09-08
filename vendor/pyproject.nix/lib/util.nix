# Small utilities for internal reuse, not exposed externally
{ lib }:
let
  inherit (builtins)
    filter
    match
    split
    head
    ;
  inherit (lib) isString;

in
rec {
  isEmptyStr = s: isString s && match " *" s == null;

  splitComma = s: if s == "" then [ ] else filter isEmptyStr (split " *, *" s);

  stripStr =
    s:
    let
      t = match "[\t ]*(.*[^\t ])[\t ]*" s;
    in
    if t == null then "" else head t;
}
