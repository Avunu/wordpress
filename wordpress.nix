{ pkgs, php, imageName }:

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
    pkgs.busybox
    pkgs.cacert
    pkgs.frankenphp
    pkgs.ghostscript
    pkgs.imagemagick
    pkgs.mysql.client
    pkgs.vips
    pkgs.wp-cli
  ];

  config = {
    Entrypoint = [ "${pkgs.busybox}/bin/sh" "/docker-entrypoint.sh" ];
    Cmd = [ "${pkgs.lib.getExe pkgs.frankenphp}" "php-server" "--root" "/var/www/html" "--listen" "0.0.0.0:80" ];
    ExposedPorts = {
      "80/tcp" = { };
    };
    Env = [
      "SERVER_NAME=0.0.0.0:80"
      "WORDPRESS_SOURCE_URL=https://wordpress.org/latest.zip"
      "WORDPRESS_DB_URL="
      "WORDPRESS_DB_HOST=localhost"
      "WORDPRESS_DB_USER=wordpress"
      "WORDPRESS_DB_PASSWORD=wordpress"
      "WORDPRESS_DB_NAME=wordpress"
      "WORDPRESS_AUTH_KEY=key"
      "WORDPRESS_SECURE_AUTH_KEY=key"
      "WORDPRESS_LOGGED_IN_KEY=key"
      "WORDPRESS_NONCE_KEY=key"
      "WORDPRESS_AUTH_SALT=key"
      "WORDPRESS_SECURE_AUTH_SALT=key"
      "WORDPRESS_LOGGED_IN_SALT=key"
      "WORDPRESS_NONCE_SALT=key"
    ];
  };

  extraCommands = ''
    # Copy WordPress files
    mkdir -p var/www/html
    cp ${./wp-config.php} wp-config.php
    cp ${./docker-entrypoint.sh} docker-entrypoint.sh
    chmod +x docker-entrypoint.sh

    # Symlink CA certificates
    ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
  '';
}
