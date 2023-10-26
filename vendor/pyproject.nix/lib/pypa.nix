{ lib, ... }:
let
  inherit (builtins) concatStringsSep filter split;
  inherit (lib) isString toLower;

in
{
  /* Normalize package name as documented in https://packaging.python.org/en/latest/specifications/name-normalization/#normalization

     Type: normalizePackageName :: string -> string

     Example:
       # readPyproject "Friendly-Bard"
       "friendly-bard"
  */
  normalizePackageName =
    let
      concatDash = concatStringsSep "-";
      splitSep = split "[-_\.]+";
    in
    name: toLower (concatDash (filter isString (splitSep name)));
}
