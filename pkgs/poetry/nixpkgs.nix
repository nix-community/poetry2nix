let
  lock = builtins.fromJSON (builtins.readFile ../../flake.lock);

  lockedNixpkgs = lock.nodes.nixpkgs.locked;

  tarball = (builtins.fetchTarball {
    url = "https://github.com/${lockedNixpkgs.owner}/${lockedNixpkgs.repo}/archive/${lockedNixpkgs.rev}.tar.gz";
    sha256 = lockedNixpkgs.narHash;
  });
in
tarball
