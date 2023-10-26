{
  # Used to find the project root
  projectRootFile = "flake.lock";

  programs.deadnix.enable = true;
  programs.statix.enable = true;
  programs.black.enable = true;
}
