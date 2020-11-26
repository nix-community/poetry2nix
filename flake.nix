{
  description = "Poetry2nix flake";

  outputs = { self }:
    {
      overlay = import ./overlay.nix;
    };
}
