{ poetry2nix, python310, runCommand, writeText }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python310;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };

  testScript = writeText "test-ml-stack-old.py" ''
    import torch
    import torchvision

    print(torch.__version__)
    print(torchvision.__version__)

    has_cuda = torch.cuda.is_available()

    print("has_cuda = {}".format(has_cuda))

    x = torch.randn(3, 3);

    if has_cuda:
        x = x.cuda()

    print(x**2)
  '';
in
# Note: torch.cuda() will print False, even if you have a GPU, when this runs *during test.*
# But if you run the script below in your shell (rather than during build), it will print True.
# Presumably this is due to sandboxing.
runCommand "ml-stack-old-test" { } ''
  ${env}/bin/python "${testScript}" > $out
''
