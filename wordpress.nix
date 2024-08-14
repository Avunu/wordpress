{ pkgs ? import <nixpkgs> {} }:

let
  wordpress = pkgs.wordpress;
  php = pkgs.php82.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [ pcov xdebug ];
  };
in
pkgs.dockerTools.buildLayeredImage {
  name = "wordpress-frankenphp-nixos";
  tag = "latest";
  contents = [
    pkgs.frankenphp
    php
    wordpress
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.gnused
  ];

  config = {
    Entrypoint = [ "/bin/bash" "/docker-entrypoint.sh" ];
    Cmd = [ "frankenphp" "php-server" "--root" "/var/www/html" "--listen" "0.0.0.0:80" ];
    ExposedPorts = {
      "80/tcp" = {};
    };
  };

  extraCommands = ''
    mkdir -p var/www/html
    cp -R ${wordpress}/* var/www/html/
    chmod -R 755 var/www/html

    cp ${./wp-config.php} var/www/html/wp-config.php
    cp ${./docker-entrypoint.sh} docker-entrypoint.sh
    chmod +x docker-entrypoint.sh
  '';
}