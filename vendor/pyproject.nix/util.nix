# Small utilities for internal reuse, not exposed externally
{ lib }:
let
  inherit (builtins) filter match split;
  inherit (lib) isString;

  isEmptyStr = s: isString s && match " *" s == null;
in
{
  splitComma = s: if s == "" then [ ] else filter isEmptyStr (split " *, *" s);
}
