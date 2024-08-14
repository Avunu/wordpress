#!/bin/bash
set -euo pipefail

# Check if the wp-config.php file exists
if [ ! -f /var/www/html/wp-config.php ]; then
    echo >&2 "WordPress not found in /var/www/html - copying now..."
    cp -R /wordpress/* /var/www/html/
    chown -R nobody:nobody /var/www/html
fi

# Generate random salts if not provided
if [ -z "${WORDPRESS_AUTH_KEY:-}" ]; then
    export WORDPRESS_AUTH_KEY=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_SECURE_AUTH_KEY=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_LOGGED_IN_KEY=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_NONCE_KEY=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_AUTH_SALT=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_SECURE_AUTH_SALT=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_LOGGED_IN_SALT=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
    export WORDPRESS_NONCE_SALT=$(head -c1m /dev/urandom | sha1sum | cut -d' ' -f1)
fi

exec "$@"