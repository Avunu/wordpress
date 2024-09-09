#!/bin/sh
set -euo pipefail

# Default WordPress URL if not provided
WORDPRESS_SOURCE_URL=${WORDPRESS_SOURCE_URL:-"https://wordpress.org/latest.zip"}

# Function to download and install WordPress
install_wordpress() {
    echo "WordPress not found. Downloading and installing from: $WORDPRESS_SOURCE_URL"
    curl -o wordpress.zip "$WORDPRESS_SOURCE_URL"
    
    # Create a temporary directory for extraction
    TEMP_DIR="/tmp/wp_install_$(date +%s)"
    mkdir -p "$TEMP_DIR"
    
    # Find WordPress files
    WP_ROOT=$(find "$TEMP_DIR" -name wp-config-sample.php -exec dirname {} \; | head -n 1)
    
    if [ -z "$WP_ROOT" ]; then
        echo "Error: WordPress files not found in the downloaded archive."
        rm -rf "$TEMP_DIR"
        exit 1
    fi
    
    # Move WordPress files to the correct location
    mv "$WP_ROOT"/* /var/www/html/
    
    # Clean up
    rm -rf "$TEMP_DIR" wordpress.zip
    chown -R nobody:nobody /var/www/html

    # Import database if WORDPRESS_DB_URL is set
    if [ -n "${WORDPRESS_DB_URL:-}" ]; then
        if command -v wp &> /dev/null; then
            import_db_wp_cli
        elif command -v mysql &> /dev/null; then
            import_db_mysql
        else
            echo "Error: Neither wp-cli nor mysql cli are available. Cannot import database."
        fi
    fi
}

# Function to import database using wp-cli
import_db_wp_cli() {
    echo "Importing database using wp-cli from: $WORDPRESS_DB_URL"
    curl -o db_dump.sql "$WORDPRESS_DB_URL"
    wp db import db_dump.sql --allow-root
    rm db_dump.sql
}

# Function to import database using mysql cli
import_db_mysql() {
    echo "Importing database using mysql from: $WORDPRESS_DB_URL"
    curl -o db_dump.sql "$WORDPRESS_DB_URL"
    mysql -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" < db_dump.sql
    rm db_dump.sql
}

# Always copy the custom wp-config.php
echo "Copying custom wp-config.php"
cp /opt/wp-config.php /var/www/html/wp-config.php
# chown nobody:nobody /var/www/html/wp-config.php
chmod 644 /var/www/html/wp-config.php


# Check if WordPress is installed
if [ ! -f /var/www/html/wp-includes/version.php ]; then
    install_wordpress
fi

exec "$@"