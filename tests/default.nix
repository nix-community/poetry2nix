{ pkgs ? import <nixpkgs> {} }:
let
  poetry = pkgs.callPackage ../pkgs/poetry { python = pkgs.python3; inherit poetry2nix; };
  poetry2nix = import ./.. { inherit pkgs; inherit poetry; };

  pep425 = pkgs.callPackage ../pep425.nix {};
  pep425Python37 = pkgs.callPackage ../pep425.nix { python = pkgs.python37; };
  pep425OSX = pkgs.callPackage ../pep425.nix { isLinux = false; };

  skipTests = builtins.filter (t: builtins.typeOf t != "list") (builtins.split "," (builtins.getEnv "SKIP_TESTS"));

in
builtins.removeAttrs
  {
    trivial = pkgs.callPackage ./trivial { inherit poetry2nix; };
    override = pkgs.callPackage ./override-support { inherit poetry2nix; };
    override-default = pkgs.callPackage ./override-default-support { inherit poetry2nix; };
    top-packages-1 = pkgs.callPackage ./common-pkgs-1 { inherit poetry2nix; };
    top-packages-2 = pkgs.callPackage ./common-pkgs-2 { inherit poetry2nix; };
    pep425 = pkgs.callPackage ./pep425 { inherit pep425; inherit pep425OSX; inherit pep425Python37; };
    env = pkgs.callPackage ./env { inherit poetry2nix; };
    git-deps = pkgs.callPackage ./git-deps { inherit poetry2nix; };
    git-deps-pinned = pkgs.callPackage ./git-deps-pinned { inherit poetry2nix; };
    cli = poetry2nix;
    path-deps = pkgs.callPackage ./path-deps { inherit poetry2nix; };
    operators = pkgs.callPackage ./operators { inherit poetry2nix; };
    preferWheel = pkgs.callPackage ./prefer-wheel { inherit poetry2nix; };

    inherit poetry;
    poetry-python2 = poetry.override { python = pkgs.python2; };

    # Pyqt5 test is waiting for nixpkgs sip bump to reach channel
    pyqt5 = pkgs.callPackage ./pyqt5 { inherit poetry2nix; };

    # Egg support not yet in channel, uncomment when channel progressed
    eggs = pkgs.callPackage ./eggs { inherit poetry2nix; };

    inherit (poetry2nix) doc;

    # manylinux requires nixpkgs with https://github.com/NixOS/nixpkgs/pull/75763
    # Once this is available in 19.09 and unstable we can re-enable the manylinux test
    manylinux = pkgs.callPackage ./manylinux { inherit poetry2nix; };
  } skipTests
