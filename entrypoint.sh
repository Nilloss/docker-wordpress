#!/bin/bash

# terminate on errors
set -e

# Start MariaDB
/usr/bin/mysqld_safe --datadir='/var/lib/mysql' --bind-address=0.0.0.0 &

# Wait for MariaDB to start
sleep 5

# Run a SQL query to create a database
mysql -u root -e "CREATE DATABASE IF NOT EXISTS wordpress;CREATE USER IF NOT EXISTS 'wordpress_user'@'localhost' IDENTIFIED BY '@>b/034NCaOi';GRANT ALL PRIVILEGES ON wordpress.* TO 'wordpress_user'@'localhost';FLUSH PRIVILEGES;"

# Check if volume is empty
if [ ! "$(ls -A "/var/www/wp-content" 2>/dev/null)" ]; then
    echo 'Setting up wp-content volume'
    # Copy wp-content from Wordpress src to volume
    cp -r /usr/src/wordpress/wp-content /var/www/
    chown -R nobody.nobody /var/www
fi
# Check if wp-secrets.php exists
if ! [ -f "/var/www/wp-content/wp-secrets.php" ]; then
    # Check that secrets environment variables are not set
    if [ ! $AUTH_KEY ] \
    && [ ! $SECURE_AUTH_KEY ] \
    && [ ! $LOGGED_IN_KEY ] \
    && [ ! $NONCE_KEY ] \
    && [ ! $AUTH_SALT ] \
    && [ ! $SECURE_AUTH_SALT ] \
    && [ ! $LOGGED_IN_SALT ] \
    && [ ! $NONCE_SALT ]; then
        echo "Generating wp-secrets.php"
        # Generate secrets
        echo '<?php' > /var/www/wp-content/wp-secrets.php
        curl -f https://api.wordpress.org/secret-key/1.1/salt/ >> /var/www/wp-content/wp-secrets.php
    fi
fi
exec "$@"
