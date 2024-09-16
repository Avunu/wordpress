<?php
// Database settings
define('DB_HOST', getenv('WORDPRESS_DB_HOST') ?: 'mysql');
define('DB_USER', getenv('WORDPRESS_DB_USER') ?: 'wordpress');
define('DB_PASSWORD', getenv('WORDPRESS_DB_PASSWORD') ?: 'wordpress');
define('DB_NAME', getenv('WORDPRESS_DB_NAME') ?: 'wordpress');
define('DB_CHARSET', 'utf8');
define('DB_COLLATE', '');

$table_prefix = getenv('WORDPRESS_TABLE_PREFIX') ?: 'wp_';

// Authentication Unique Keys and Salts
define('AUTH_KEY',         getenv('WORDPRESS_AUTH_KEY'));
define('SECURE_AUTH_KEY',  getenv('WORDPRESS_SECURE_AUTH_KEY'));
define('LOGGED_IN_KEY',    getenv('WORDPRESS_LOGGED_IN_KEY'));
define('NONCE_KEY',        getenv('WORDPRESS_NONCE_KEY'));
define('AUTH_SALT',        getenv('WORDPRESS_AUTH_SALT'));
define('SECURE_AUTH_SALT', getenv('WORDPRESS_SECURE_AUTH_SALT'));
define('LOGGED_IN_SALT',   getenv('WORDPRESS_LOGGED_IN_SALT'));
define('NONCE_SALT',       getenv('WORDPRESS_NONCE_SALT'));

// Debug mode
define('WP_DEBUG', !!getenv('WORDPRESS_DEBUG', '') );

// Extra WordPress configs
if ($extra = getenv('WORDPRESS_CONFIG_EXTRA')) {
    eval($extra);
}

// If we're behind a proxy server and using HTTPS, we need to alert WordPress of that fact
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
    $_SERVER['HTTPS'] = 'on';
}

if (isset($_SERVER['HTTP_HOST'])) {
    if ($_SERVER['HTTP_HOST'] === 'localhost') {
        define('WP_SITEURL', 'http://localhost' . $_SERVER['SERVER_PORT']);
        define('WP_HOME', 'http://localhost' . $_SERVER['SERVER_PORT']);
        define('FORCE_SSL_ADMIN', false);
    } else {
        define('WP_HOME', 'https://' . $_SERVER['HTTP_HOST']);
        define('WP_SITEURL', 'https://' . $_SERVER['HTTP_HOST']);
        define('FORCE_SSL_ADMIN', true);
    }
}

define('FS_METHOD', 'direct');
define('WP_AUTO_UPDATE_CORE', 'minor');
define('CONCATENATE_SCRIPTS', false);
define('DISALLOW_FILE_EDIT', true);
define('DISABLE_WP_CRON', true);
define('WP_CACHE', true);
define('WP_POST_REVISIONS', 5);
define('EMPTY_TRASH_DAYS', 7);

/* Add any custom values between this line and the "stop editing" line. */



/* That's all, stop editing! Happy publishing. */

/** Absolute path to the WordPress directory. */
if ( ! defined( 'ABSPATH' ) ) {
	define( 'ABSPATH', __DIR__ . '/' );
}

/** Sets up WordPress vars and included files. */
require_once ABSPATH . 'wp-settings.php';