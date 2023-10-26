{ pkgs, lib }:
{
  lib = import ./lib { inherit lib; };
  fetchers = import ./fetchers { inherit pkgs lib; };
}
