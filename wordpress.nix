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

    cat > var/www/html/wp-config-docker.php << EOF
    <?php
    // Database settings
    define( 'DB_HOST', getenv('WORDPRESS_DB_HOST') );
    define( 'DB_USER', getenv('WORDPRESS_DB_USER') );
    define( 'DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') );
    define( 'DB_NAME', getenv('WORDPRESS_DB_NAME') );
    define( 'DB_CHARSET', 'utf8' );
    define( 'DB_COLLATE', '' );

    \$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

    // Authentication Unique Keys and Salts
    define( 'AUTH_KEY',         getenv('WORDPRESS_AUTH_KEY') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'SECURE_AUTH_KEY',  getenv('WORDPRESS_SECURE_AUTH_KEY') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'LOGGED_IN_KEY',    getenv('WORDPRESS_LOGGED_IN_KEY') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'NONCE_KEY',        getenv('WORDPRESS_NONCE_KEY') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'AUTH_SALT',        getenv('WORDPRESS_AUTH_SALT') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'SECURE_AUTH_SALT', getenv('WORDPRESS_SECURE_AUTH_SALT') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'LOGGED_IN_SALT',   getenv('WORDPRESS_LOGGED_IN_SALT') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );
    define( 'NONCE_SALT',       getenv('WORDPRESS_NONCE_SALT') ?: '$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)' );

    // Debug mode
    define( 'WP_DEBUG', !!getenv('WORDPRESS_DEBUG') );

    // Extra WordPress configs
    if ( \$extra = getenv('WORDPRESS_CONFIG_EXTRA') ) {
        eval(\$extra);
    }

    // If we're behind a proxy server and using HTTPS, we need to alert WordPress of that fact
    if (isset(\$_SERVER['HTTP_X_FORWARDED_PROTO']) && \$_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
        \$_SERVER['HTTPS'] = 'on';
    }

    // HTTPS port is always 443 in the container environment.
    define( 'FORCE_SSL_ADMIN', true );

    if (isset(\$_SERVER['HTTP_HOST'])) {
        define( 'WP_HOME', 'https://' . \$_SERVER['HTTP_HOST'] );
        define( 'WP_SITEURL', 'https://' . \$_SERVER['HTTP_HOST'] );
    }

    // That's all, stop editing! Happy publishing.
    if ( ! defined( 'ABSPATH' ) ) {
        define( 'ABSPATH', dirname( __FILE__ ) . '/' );
    }

    require_once( ABSPATH . 'wp-settings.php' );
    EOF

    cat > var/www/html/wp-config.php << EOF
    <?php
    if (file_exists(dirname(__FILE__) . '/wp-config-docker.php')) {
        require_once(dirname(__FILE__) . '/wp-config-docker.php');
    } else {
        // Fallback to a standard wp-config.php if the Docker-specific one doesn't exist
        require_once(dirname(__FILE__) . '/wp-config-sample.php');
    }
    EOF

    cat > docker-entrypoint.sh << EOF
    #!/bin/bash
    set -euo pipefail

    # Check if the wp-config.php file exists
    if [ ! -f /var/www/html/wp-config.php ]; then
        echo >&2 "WordPress not found in /var/www/html - copying now..."
        cp -R ${wordpress}/* /var/www/html/
        chown -R nobody:nobody /var/www/html
    fi

    exec "\$@"
    EOF

    chmod +x docker-entrypoint.sh
  '';
}