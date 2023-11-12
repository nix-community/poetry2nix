{ pkgs, lib }:
{
  lib = import ./lib { inherit lib; };
  fetchers = pkgs.callPackage ./fetchers { };
}
