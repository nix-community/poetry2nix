{ lib, poetry2nix, python3, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    python = python3;
    pyproject = ./pyproject.toml;
    poetrylock = ./poetry.lock;
    preferWheels = true;
  };
  py = env.python;
in
# Note: torch.cuda() will print False, even if you have a GPU, when this runs *during test.*
  # But if you run the script below in your shell (rather than during build), it will print True.
  # Presumably this is due to sandboxing.
runCommand "ml-stack-test" { } ''
  ${env}/bin/python -c 'import torch; import torchvision; print(torch.__version__); print(torchvision.__version__); print(torch.cuda.is_available()); x = torch.randn(3,3); x = x.cuda() if torch.cuda.is_available() else x; print(x**2)' > $out
''
