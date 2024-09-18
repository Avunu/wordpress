#!/bin/sh
set -e

# set shell as /bin/sh
export SHELL=/bin/sh
export WP_CLI_CUSTOM_SHELL=/bin/sh

# Function to run wp-cron
run_wp_cron() {
    while true; do
        echo "Running WordPress cron events"
        if ! wp cron event run --all --due-now --allow-root --path=/var/www/html; then
            echo "Error running wp-cron. Retrying in 60 seconds."
        fi
        sleep 60
    done
}

# If PROC_TYPE=worker, run cron jobs in the background
if [ "$PROC_TYPE" = "worker" ]; then
    echo "Starting wp-cron worker process"
    run_wp_cron
fi

# Default WordPress URL if not provided
WORDPRESS_SOURCE_URL=${WORDPRESS_SOURCE_URL:-"https://wordpress.org/latest.zip"}

# Function to download and install WordPress
install_wordpress() {
    echo "WordPress not found. Downloading and installing from: $WORDPRESS_SOURCE_URL"
    wget -O wordpress.zip "$WORDPRESS_SOURCE_URL"
    
    # Create a temporary directory for extraction
    TEMP_DIR="/tmp/wordpress"
    mkdir -p "$TEMP_DIR"
    unzip wordpress.zip -d "$TEMP_DIR"
    
    # Find WordPress files
    WP_ROOT=$(find "$TEMP_DIR" -name wp-config-sample.php -exec dirname {} \; | head -n 1)
    
    if [ -z "$WP_ROOT" ]; then
        echo "Error: WordPress files not found in the downloaded archive."
        exit 1
    fi
    
    # Move WordPress files to the correct location
    mv "$WP_ROOT"/* /var/www/html/
    
    # Clean up
    rm -rf "$TEMP_DIR" wordpress.zip
    # chown -R nobody:nobody /var/www/html

    # Import database if WORDPRESS_DB_URL is set
    if [ -n "${WORDPRESS_DB_URL:-}" ]; then
        if command -v wp >/dev/null 2>&1; then
            import_db_wp_cli
        elif command -v mysql >/dev/null 2>&1; then
            import_db_mysql
        else
            echo "Error: Neither wp-cli nor mysql cli are available. Cannot import database."
        fi
    fi
}

# Function to import database using wp-cli
import_db_wp_cli() {
    echo "Importing database using wp-cli from: $WORDPRESS_DB_URL"
    wget -O db_dump.sql "$WORDPRESS_DB_URL"
    wp db import db_dump.sql --allow-root --path=/var/www/html
    rm db_dump.sql
}

# Function to import database using mysql cli
import_db_mysql() {
    echo "Importing database using mysql from: $WORDPRESS_DB_URL"
    wget -O db_dump.sql "$WORDPRESS_DB_URL"
    mysql -h"$WORDPRESS_DB_HOST" -u"$WORDPRESS_DB_USER" -p"$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" < db_dump.sql
    rm db_dump.sql
}

# function to set up the salts
setup_salts() {
    echo "Setting up salts"
    echo "<?php" > /var/www/html/wp-salts.php
    wget -qO- https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/html/wp-salts.php
}

# Always copy the custom wp-config.php
echo "Copying custom wp-config.php"
cp /wp-config.php /var/www/html/wp-config.php
chmod 644 /var/www/html/wp-config.php

# Check if WordPress is installed
if [ ! -f /var/www/html/wp-includes/version.php ]; then
    install_wordpress
fi

# Check if salts are needed
if [ ! -f /var/www/html/wp-salts.php ]; then
    setup_salts
fi

# Always copy the custom mu-plugins
echo "Copying custom mu-plugins"
rm -rf /var/www/html/wp-content/mu-plugins
mkdir -p /var/www/html/wp-content/mu-plugins
cp -a /mu-plugins/. /var/www/html/wp-content/mu-plugins/
chmod 755 /var/www/html/wp-content/mu-plugins

# Execute the main command
exec "$@"