{ pkgs, php, imageName }:

let
  customPhp = (php.override {
    # Sapi flags
    cgiSupport = false;
    cliSupport = true;
    fpmSupport = false;
    pearSupport = false;
    pharSupport = true;
    phpdbgSupport = false;

    # Misc flags
    apxs2Support = false;
    argon2Support = true;
    cgotoSupport = false;
    embedSupport = true;
    ipv6Support = true;
    staticSupport = false;
    systemdSupport = false;
    valgrindSupport = false;
    zendMaxExecutionTimersSupport = true;
    zendSignalsSupport = false;
    ztsSupport = true;

  }).overrideAttrs (oldAttrs: rec {
    # Use Clang instead of GCC
    stdenv = pkgs.clangStdenv;

    # optimizations
    extraConfig = ''
      CC = "${pkgs.llvmPackages_19.clang}/bin/clang";
      CXX = "${pkgs.llvmPackages_19.clang}/bin/clang++";
      CFLAGS="$CFLAGS -march=x86-64-v3 -mtune=x86-64-v3 -O3 -ffast-math -flto"
      CXXFLAGS="$CXXFLAGS -march=x86-64-v3 -mtune=x86-64-v3 -O3 -ffast-math -flto"
      LDFLAGS="$LDFLAGS -flto"
    '';

    # Explicitly enable XML support
    configureFlags = (oldAttrs.configureFlags or [ ]) ++ [
      "--enable-xml"
      "--with-libxml"
    ];

    buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
      pkgs.libxml2.dev
    ];
  });

  phpWithExtensions = customPhp.withExtensions ({ all, ... }: with all; [
    # Required extensions
    mysqli

    # Highly recommended extensions
    ctype
    curl
    dom
    exif
    fileinfo
    filter
    imagick
    intl
    mbstring
    openssl
    pdo
    pdo_mysql
    tokenizer
    zip
    zlib

    # Recommended for caching
    opcache

    # Optional extensions for improved functionality
    gd
    iconv
    sodium

    # Development extensions (uncomment if needed in production)
    # xdebug
  ]);

  phpBuild = phpWithExtensions.buildEnv {
    extraConfig = builtins.readFile ./conf/php.ini;
  };

  wp-cli = (pkgs.wp-cli.override {
    php = phpBuild;
  });

  frankenphp = (pkgs.frankenphp.override {
    php = phpBuild;
  }).overrideAttrs (oldAttrs: {
    # Here we override the let...in section
    phpEmbedWithZts = phpBuild;
    phpUnwrapped = phpBuild.unwrapped;
    phpConfig = "${phpBuild.unwrapped.dev}/bin/php-config";
  });

  caddyfile = pkgs.writeText "Caddyfile" (builtins.readFile ./conf/Caddyfile);

  start-server = pkgs.writeScriptBin "start-server" ''
    #!${pkgs.busybox}/bin/sh
    # Start Caddy/frankenphp
    ${pkgs.lib.getExe frankenphp} run --config ${caddyfile} --adapter caddyfile
  '';

  docker-entrypoint = pkgs.writeScriptBin "docker-entrypoint" (builtins.readFile ./docker-entrypoint.sh);

in
pkgs.dockerTools.buildLayeredImage {
  name = imageName;
  tag = "latest";
  contents = [
    phpBuild
    pkgs.busybox
    pkgs.cacert
    pkgs.ghostscript
    pkgs.imagemagick
    pkgs.mysql.client
    pkgs.vips
    pkgs.zip
    wp-cli
  ];

  config = {
    Entrypoint = [ "${pkgs.busybox}/bin/sh" "${pkgs.lib.getExe docker-entrypoint}" ];
    Cmd = [ "${pkgs.lib.getExe start-server}" ];
    ExposedPorts = {
      "80/tcp" = { };
    };
  };

  extraCommands = ''
    # set up /tmp
    mkdir -p tmp
    chmod 1777 tmp

    # enable Caddy logging
    mkdir -p var/log/caddy
    touch var/log/caddy/access.log
    touch var/log/caddy/error.log
    chmod -R 777 var/log/caddy

    # Copy WordPress files
    mkdir -p var/www/html
    cp ${./conf/wp-config.php} wp-config.php

    # copy must-use plugins
    mkdir mu-plugins
    cp -r ${./mu-plugins}/. mu-plugins/

    # Symlink CA certificates
    ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt

    # Set up PHP-FPM socket directory
    mkdir -p run
    chmod 777 run

    # Symlink busybox for bash and env
    mkdir -p usr/bin
    ln -s ${pkgs.busybox}/bin/busybox usr/bin/bash
    ln -s ${pkgs.busybox}/bin/busybox usr/bin/env
  '';
}
