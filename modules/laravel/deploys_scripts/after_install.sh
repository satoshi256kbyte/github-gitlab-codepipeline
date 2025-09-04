#!/bin/bash
chown -R apache:apache /var/www/html
chmod -R 755 /var/www/html
chmod -R 777 /var/www/html/storage
chmod -R 777 /var/www/html/bootstrap/cache
echo "Create SQLite database(demo only)"
cd /var/www/html/

# Install Composer dependencies
composer install --no-dev --optimize-autoloader
composer update --no-dev

touch database/database.sqlite
chmod 664 database/database.sqlite
chown apache:apache database/database.sqlite
php artisan migrate
