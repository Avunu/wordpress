{ pkgs, php, imageName }:

let
  customPhp = (php.override {
    # Sapi flags
    cgiSupport = false;
    cliSupport = true; # CLI is needed for FrankenPHP
    fpmSupport = false;
    pearSupport = false;
    pharSupport = true; # Needed for Composer and some WordPress plugins
    phpdbgSupport = false;

    # Misc flags
    apxs2Support = false;
    argon2Support = true; # Useful for password hashing
    cgotoSupport = false;
    embedSupport = true; # Needed for FrankenPHP
    staticSupport = false;
    ipv6Support = true;
    zendSignalsSupport = false;
    zendMaxExecutionTimersSupport = true;
    systemdSupport = false;
    valgrindSupport = false;
    ztsSupport = true; # Needed for FrankenPHP
  }).overrideAttrs (oldAttrs: {
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
    extraConfig = ''
      memory_limit = 256M
      upload_max_filesize = 100M
      post_max_size = 100M
      max_execution_time = 300
      zend.max_allowed_stack_size = -1
      opcache.enable = 1
      ffi.enable = 1
    '';
  };

  frankenphp = (pkgs.frankenphp.override {
    php = phpBuild;
  }).overrideAttrs (oldAttrs: {
    # Here we override the let...in section
    phpEmbedWithZts = phpBuild;
    phpUnwrapped = phpBuild.unwrapped;
    phpConfig = "${phpBuild.unwrapped.dev}/bin/php-config";
    # no musl support
    pieBuild = false;
  });

  wp-cli = (pkgs.wp-cli.override {
    php = phpBuild;
  });

in
pkgs.dockerTools.buildLayeredImage {
  name = imageName;
  tag = "latest";
  contents = [
    frankenphp
    phpBuild
    pkgs.busybox
    pkgs.cacert
    pkgs.ghostscript
    pkgs.imagemagick
    pkgs.mysql.client
    pkgs.vips
    wp-cli
  ];

  config = {
    Entrypoint = [ "${pkgs.busybox}/bin/sh" "/docker-entrypoint.sh" ];
    Cmd = [ "${pkgs.lib.getExe frankenphp}" "php-server" "--root" "/var/www/html" "--listen" "0.0.0.0:80" ];
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
