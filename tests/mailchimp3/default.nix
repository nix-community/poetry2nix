{ poetry2nix, runCommand }:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ./.;
  };
in
runCommand "mailchimp3-test" { } ''
  ${env}/bin/python -c 'import mailchimp3; mailchimp3.MailChimp'
  touch $out
''
