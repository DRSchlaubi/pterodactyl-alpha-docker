#!/bin/sh

###
# /entrypoint.sh - Manages the startup of pterodactyl panel
###

# Prep Container for usage
init() {
    # Create the storage/cache directories
    if [ ! -d /data/storage ]; then
        while IFS= read -r line; do
            mkdir -p "/data/${line}"
        done < .storage.tmpl
        chown -R nginx:nginx /data/storage
    fi

    if [ ! -d /data/cache ]; then
        mkdir -p /data/cache
        chown -R nginx:nginx /data/cache
    fi

    # destroy links (or files) and recreate them
    rm -rf storage
    ln -s /data/storage storage

    rm -rf bootstrap/cache
    ln -s /data/cache bootstrap/cache

    rm -rf .env
    ln -s /data/pterodactyl.conf .env
}

# Runs the initial configuration on every startup
startServer() {

    # Initial setup
    if [ ! -e /data/pterodactyl.conf ]; then
        echo "Running first time setup..."

        # Generate base template
        touch /data/pterodactyl.conf
        {
          echo "##";
          echo "# Generated on: $(date +"%B %d %Y, %H:%M:%S")";
          echo "# This file was generated on first start and contains ";
          echo "# the key for sensitive information. All panel configuration ";
          echo "# can be done here using the normal method (NGINX not included!),";
          echo "# or using Docker's environment variables parameter.";
          echo "##";
          echo "";
          echo "APP_KEY=SomeRandomString3232RandomString"
        } >> /data/pterodactyl.conf

        sleep 5

        echo ""
        echo "Generating key..."
        sleep 1
        php artisan key:generate --force --no-interaction

        echo ""
        echo "Creating & seeding database..."
        sleep 1
        php artisan migrate --force
        php artisan db:seed --force
    fi

    # Allows Users to give MySQL/cache sometime to start up.
    if [ "${STARTUP_TIMEOUT}" -gt "0" ]; then
        echo "Starting Pterodactyl ${PANEL_VERSION} in ${STARTUP_TIMEOUT} seconds..."
        sleep "${STARTUP_TIMEOUT}"
    else
        echo "Starting Pterodactyl ${PANEL_VERSION}..."
    fi

    if [ "${SSL}" = "true" ]; then
        envsubst "${SSL_CERT},${SSL_CERT_KEY}" \
        < /etc/nginx/templates/https.conf > /etc/nginx/conf.d/default.conf
    else
        echo "[Warning] Disabling HTTPS"
        cat /etc/nginx/templates/http.conf > /etc/nginx/conf.d/default.conf
    fi

    # Determine if workers should be enabled or not
    if [ "${DISABLE_WORKERS}" != "true" ]; then
        /usr/sbin/crond -f -l 0 &
        php /var/www/html/artisan queue:work database --queue=high,standard,low --sleep=3 --tries=3 &
    else
        echo "[Warning] Disabling Workers (pteroq & cron); It is recommended to keep these enabled unless you know what you are doing."
    fi

    /usr/sbin/php-fpm7 --nodaemonize -c /etc/php7 &

    exec /usr/sbin/nginx -g "daemon off;"
}

## Start ##

init

case "${1}" in
    p:start)
        startServer
        ;;
    *)
        exec "${@}"
        ;;
esac