{
  description = "FrankenPHP with latest PHP versions";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    # frankenwp = {
    #   url = "github:StephenMiracle/frankenwp";
    #   flake = false;
    # };
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (final: prev: {
              phpCommonConfig = {
                embedSupport = true;
                ztsSupport = true;
                apxs2Support = false;
                systemdSupport = false;
                phpdbgSupport = false;
                cgiSupport = false;
                fpmSupport = false;
              };

              optimizePhp = phpPackage: (phpPackage.override final.phpCommonConfig).withExtensions 
                ({ all, ... }: with all; [
                  curl dom exif fileinfo gd iconv imagick intl
                  mbstring mysqli opcache openssl sodium xml zip
                ]);

              php81Optimized = final.optimizePhp prev.php81;
              php82Optimized = final.optimizePhp prev.php82;
              php83Optimized = final.optimizePhp prev.php83;

              buildwordpress-php = { php, name }: 
                final.dockerTools.buildLayeredImage {
                  inherit name;
                  tag = "latest";
                  contents = [
                    final.frankenphp
                    php
                    final.busybox
                    final.cacert
                    final.curl
                    final.ghostscript
                    final.libxml2
                    final.mariadb.client
                    final.unzip
                  ];
                  extraCommands = ''
                    mkdir -p var/www/html /usr/bin/
                    cp ${./wp-config.php} wp-config.php
                    cp ${./docker-entrypoint.sh} docker-entrypoint.sh
                    chmod +x docker-entrypoint.sh
                    ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
                    ln -s ${pkgs.busybox}/bin/sh /usr/bin/bash
                  '';
                  config = {
                    Entrypoint = [ "/docker-entrypoint.sh" ];
                    Cmd = [ "frankenphp" "php-server" "--root" "/var/www/html" "--listen" "0.0.0.0:80" ];
                    ExposedPorts = {
                      "80/tcp" = {};
                    };
                    Env = [
                      "PHP_INI_DIR=/usr/local/etc/php"
                      "WORDPRESS_VERSION=latest"
                      "WORDPRESS_SHA1="
                      "WORDPRESS_DB_HOST=localhost"
                      "WORDPRESS_DB_USER=wordpress"
                      "WORDPRESS_DB_PASSWORD=wordpress"
                      "WORDPRESS_DB_NAME=wordpress"
                      "WORDPRESS_TABLE_PREFIX=wp_"
                    ];
                  };
                };
            })
          ];
        };
      in {
        packages = {
          wordpress-php81 = pkgs.buildwordpress-php {
            php = pkgs.php81Optimized;
            name = "frankenphp-php81";
          };
          wordpress-php82 = pkgs.buildwordpress-php {
            php = pkgs.php82Optimized;
            name = "frankenphp-php82";
          };
          wordpress-php83 = pkgs.buildwordpress-php {
            php = pkgs.php83Optimized;
            name = "frankenphp-php83";
          };
        };
      }
    );
}