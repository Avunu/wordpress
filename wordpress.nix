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
    curl
    dom
    exif
    fileinfo
    filter
    imagick
    intl
    mbstring
    openssl
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
    extraConfig = ''
      ; Memory limits
      memory_limit = 512M					 ; Increased to allow more memory for PHP
      max_execution_time = 300				; Allow longer execution time if needed
      max_input_time = 120					; Extend input processing time

      ; Opcache settings
      opcache.enable = 0
      opcache.memory_consumption = 128		; Increase opcache memory to improve script caching
      opcache.max_accelerated_files = 4000	; Higher number of files cached
      opcache.interned_strings_buffer = 8	 ; Increased for interned strings
      opcache.jit_buffer_size = 64M		   ; Enable JIT with a larger buffer
      opcache.jit = 0				   ; Enable JIT compilation
      opcache.validate_timestamps = 0		 ; Keep enabled to handle dynamic file changes
      opcache.revalidate_freq = 2			 ; Check for file changes every 60 seconds

      ; Error handling
      error_reporting = E_ERROR | E_WARNING | E_PARSE | E_CORE_ERROR | E_CORE_WARNING | E_COMPILE_ERROR | E_COMPILE_WARNING | E_RECOVERABLE_ERROR
      display_errors = On
      display_startup_errors = On
      log_errors = On
      error_log = /dev/stderr
      log_errors_max_len = 1024
      ignore_repeated_errors = On
      ignore_repeated_source = Off
      html_errors = On

      ; Database connection pooling
      mysqli.max_persistent = 1			   ; Allow more persistent connections for efficiency
      mysqli.allow_persistent = 1			 ; Enable persistent connections

      ; Security settings
      upload_max_filesize = 100M
      post_max_size = 100M
      zend.max_allowed_stack_size = 64M
      ffi.enable = 0						  ; Disable FFI for security reasons
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
    pkgs.bashInteractive
    pkgs.cacert
    pkgs.coreutils
    pkgs.ghostscript
    pkgs.imagemagick
    pkgs.mysql.client
    pkgs.ncurses
    pkgs.unzip
    pkgs.vips
    pkgs.wget
    wp-cli
  ];

  config = {
    Entrypoint = [ "${pkgs.lib.getExe pkgs.bashInteractive}" "/docker-entrypoint.sh" ];
    Cmd = [ "${pkgs.lib.getExe frankenphp}" "run" "--config" "/etc/caddy/Caddyfile" ];
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
    	# set up /tmp
    	mkdir -p tmp
    	chmod 1777 tmp

    	# copy Caddyfile
    	mkdir -p etc/caddy
    	cp ${./Caddyfile} etc/caddy/Caddyfile

    	# enable Caddy logging
    	mkdir -p var/log/caddy
    	touch var/log/caddy/access.log
    	touch var/log/caddy/error.log
    	chmod -R 777 var/log/caddy

    	# Copy WordPress files
    	mkdir -p var/www/html
    	cp ${./wp-config.php} wp-config.php
    	cp ${./docker-entrypoint.sh} docker-entrypoint.sh
    	chmod +x docker-entrypoint.sh

    	# copy must-use plugins
    	mkdir mu-plugins
    	cp ${./mu-plugins/loopback.php} mu-plugins/

    	# Symlink CA certificates
    	ln -s ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt

    	# # Symlink busybox for bash and env
    	# mkdir -p usr/bin
    	# ln -s ${pkgs.busybox}/bin/busybox usr/bin/bash
    	# ln -s ${pkgs.busybox}/bin/busybox usr/bin/env
  '';
}
