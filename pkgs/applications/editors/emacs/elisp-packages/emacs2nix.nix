let
  pkgs = import ../../../../.. { };

  src = pkgs.fetchgit {
    url = "https://github.com/nix-community/emacs2nix.git";
    fetchSubmodules = true;
    rev = "5c143ea2ec99dd4709c27814ce833001b08d59bc";
    sha256 = "sha256-JDyJMvD2+WFXMs31Hp6IKJDuALPksS5AjQjNSXH1qqU=";
  };
in
pkgs.mkShell {

  packages = [
    pkgs.bash
  ];

  EMACS2NIX = src;

  shellHook = ''
    export PATH=$PATH:${src}
  '';

}
