{ pkgs ? import <nixpkgs> {} }:

let
  phpBuild = php.buildEnv {
    extensions = { all, enabled }: with all; enabled ++ [
      # Required extensions
      mysqli

      # Highly recommended extensions
      curl
      dom
      exif
      fileinfo
      imagick
      intl
      mbstring
      openssl
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
  name = imageName;
  tag = "latest";
  contents = [
    phpBuild
    pkgs.bashInteractive
    pkgs.coreutils
    pkgs.curl
    pkgs.frankenphp
    pkgs.ghostscript
    pkgs.gnused
    pkgs.imagemagick
    pkgs.unzip
    pkgs.vips
  ];

  config = {
    Entrypoint = [ "/bin/bash" "/docker-entrypoint.sh" ];
    Cmd = [ "frankenphp" "php-server" "--root" "/var/www/html" "--listen" "0.0.0.0:80" ];
    ExposedPorts = {
      "80/tcp" = {};
    };
    Env = [
      "WORDPRESS_SOURCE_URL=https://wordpress.org/latest.zip"
      "WORDPRESS_DB_HOST=localhost"
      "WORDPRESS_DB_USER=wordpress"
      "WORDPRESS_DB_PASSWORD=wordpress"
      "WORDPRESS_DB_NAME=wordpress"
    ];
  };

  extraCommands = ''
    mkdir -p var/www/html
    cp ${./wp-config.php} var/www/html/wp-config.php
    cp ${./docker-entrypoint.sh} docker-entrypoint.sh
    chmod +x docker-entrypoint.sh
  '';
}