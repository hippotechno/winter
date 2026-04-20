#!/usr/bin/env sh
set -eu

cd /var/www/html

mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/testing \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

if [ "${CHOWN_STORAGE:-true}" = "true" ]; then
    chown -R www-data:www-data storage
fi
chown -R www-data:www-data bootstrap/cache

if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
    echo "RUN_MIGRATIONS=true => chạy php artisan winter:up"
    su -s /bin/sh www-data -c "php artisan winter:up --no-interaction"
fi

exec apache2-foreground
