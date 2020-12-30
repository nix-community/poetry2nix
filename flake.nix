{
  description = "Poetry2nix flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:NixOS/nixpkgs";

  outputs = { self, nixpkgs, flake-utils }:
    {
      overlay = import ./overlay.nix;
    } // (flake-utils.lib.eachDefaultSystem (system:
      let
        myNixpkgs = import nixpkgs {
          inherit system;
          overlays = [ self.overlay ];
        };
      in
      rec {
        packages = {
          inherit (myNixpkgs) poetry;
        };
        defaultPackage = packages.poetry;

        apps = {
          poetry = flake-utils.lib.mkApp { drv = packages.poetry; };
        };

        defaultApp = apps.poetry;
      }));
}
