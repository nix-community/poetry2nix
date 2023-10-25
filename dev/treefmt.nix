{ pkgs, ... }: {
  # Used to find the project root
  projectRootFile = "flake.lock";

  settings.formatter = {
    nix = {
      command = "sh";
      options = [
        "-eucx"
        ''
          ${pkgs.lib.getExe pkgs.nixpkgs-fmt} "$@"
        ''
        "--"
      ];
      includes = [ "*.nix" ];
      excludes = [ ];
    };

    python = {
      command = "sh";
      options = [
        "-eucx"
        ''
          ${pkgs.lib.getExe pkgs.python3.pkgs.black} "$@"
        ''
        "--" # this argument is ignored by bash
      ];
      includes = [ "*.py" ];
    };
  };
}
