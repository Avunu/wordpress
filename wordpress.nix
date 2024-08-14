{ pkgs ? import <nixpkgs> {} }:

let
  wordpress = pkgs.wordpress;
  php = pkgs.php83.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [
      # Required extensions
      mysqli

      # Highly recommended extensions
      curl
      dom
      exif
      fileinfo
      hash
      imagick
      intl
      mbstring
      openssl
      pcre
      xml
      zip

      # Recommended for caching (choose one or more as needed)
      opcache
      # redis

      # Optional extensions for improved functionality
      gd
      iconv
      sodium

      # Development extensions (can be removed in production)
      # xdebug
    ];
    extraConfig = ''
      memory_limit = 256M
      upload_max_filesize = 100M
      post_max_size = 100M
      max_execution_time = 300
    '';
  };
in
pkgs.dockerTools.buildLayeredImage {
  name = "wordpress";
  tag = "latest";
  contents = [
    php
    wordpress
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.frankenphp
    pkgs.ghostscript
    pkgs.gnused
    pkgs.imagemagick
    pkgs.vips
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