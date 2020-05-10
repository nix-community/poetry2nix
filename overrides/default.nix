{ pkgs ? import <nixpkgs> { }
, lib ? pkgs.lib
, stdenv ? pkgs.stdenv
}:

lib.foldr lib.composeExtensions (self: super: { }) [
  # Overrides applied to all derivations
  (import ./universal.nix { inherit pkgs lib stdenv; })
  # Overrides only applied to sdists
  (import ./sdist.nix { inherit pkgs lib stdenv; })
  # Overrides only applied to wheels
  # (import ./wheels.nix { inherit pkgs lib stdenv; })
]
