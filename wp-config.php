<?php
// Database settings
define( 'DB_HOST', getenv('WORDPRESS_DB_HOST') ?: 'mysql' );
define( 'DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress' );
define( 'DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'wordpress' );
define( 'DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress' );
define( 'DB_CHARSET', 'utf8' );
define( 'DB_COLLATE', '' );

$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

// Authentication Unique Keys and Salts
define( 'AUTH_KEY',         getenv('WORDPRESS_AUTH_KEY') );
define( 'SECURE_AUTH_KEY',  getenv('WORDPRESS_SECURE_AUTH_KEY') );
define( 'LOGGED_IN_KEY',    getenv('WORDPRESS_LOGGED_IN_KEY') );
define( 'NONCE_KEY',        getenv('WORDPRESS_NONCE_KEY') );
define( 'AUTH_SALT',        getenv('WORDPRESS_AUTH_SALT') );
define( 'SECURE_AUTH_SALT', getenv('WORDPRESS_SECURE_AUTH_SALT') );
define( 'LOGGED_IN_SALT',   getenv('WORDPRESS_LOGGED_IN_SALT') );
define( 'NONCE_SALT',       getenv('WORDPRESS_NONCE_SALT') );

// Debug mode
define( 'WP_DEBUG', !!getenv('WORDPRESS_DEBUG') );

// Extra WordPress configs
if ( $extra = getenv('WORDPRESS_CONFIG_EXTRA') ) {
    eval($extra);
}

// If we're behind a proxy server and using HTTPS, we need to alert WordPress of that fact
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

// HTTPS port is always 443 in the container environment.
define( 'FORCE_SSL_ADMIN', true );

if (isset($_SERVER['HTTP_HOST'])) {
    define( 'WP_HOME', 'https://' . $_SERVER['HTTP_HOST'] );
    define( 'WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST'] );
}

define('FS_METHOD', 'direct');
define('WP_AUTO_UPDATE_CORE', 'minor');
define('CONCATENATE_SCRIPTS', false);
define('DISALLOW_FILE_EDIT', true);

// That's all, stop editing! Happy publishing.
if ( ! defined( 'ABSPATH' ) ) {
    define( 'ABSPATH', dirname( __FILE__ ) . '/' );
}

require_once( ABSPATH . 'wp-settings.php' );