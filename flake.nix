{
  description = "Poetry2nix flake";

  edition = 201909;

  outputs = { self, nixpkgs }: let
    # TODO: There must be a better way to provide arch-agnostic flakes..
    systems = [ "x86_64-linux" "i686-linux" "x86_64-darwin" "aarch64-linux" ];
    forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    # Memoize nixpkgs for different platforms for efficiency.
    nixpkgsFor = forAllSystems (system:
      import nixpkgs {
        inherit system;
        overlays = [ self.overlay ];
      }
    );

  in {

    overlay = import ./overlay.nix;

    # TODO: I feel like `packages` is the wrong place for the poetry2nix attr
    packages = forAllSystems (system: {
      inherit (nixpkgsFor.${system}) poetry poetry2nix;
    });

  };
}
