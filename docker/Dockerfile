FROM php:8.3-apache-bookworm

ARG BUILD_DATE=unknown
ARG VCS_REF=unknown
ARG GITHUB_TOKEN=

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${VCS_REF}"

ENV APACHE_DOCUMENT_ROOT=/var/www/html \
    APP_ENV=production \
    APP_DEBUG=false \
    XDEBUG_MODE=debug,develop \
    XDEBUG_START_WITH_REQUEST=yes \
    XDEBUG_CLIENT_HOST=host.docker.internal \
    XDEBUG_CLIENT_PORT=9003 \
    XDEBUG_IDEKEY=VSCODE \
    XDEBUG_DISCOVER_CLIENT_HOST=0 \
    COMPOSER_ALLOW_SUPERUSER=1 \
    COMPOSER_PROCESS_TIMEOUT=1800 \
    COMPOSER_MAX_PARALLEL_HTTP=4

RUN printf 'Acquire::Retries "5";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99network \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        git \
        openssh-client \
        unzip \
        libzip-dev \
        libicu-dev \
        libpq-dev \
        libonig-dev \
        libxml2-dev \
        libpng-dev \
        libjpeg62-turbo-dev \
        libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j"$(nproc)" \
        bcmath \
        exif \
        ftp \
        gd \
        intl \
        mbstring \
        opcache \
        pdo_mysql \
        pdo_pgsql \
        zip \
    && pecl install xdebug \
    && docker-php-ext-enable xdebug \
    && a2enmod rewrite headers \
    && sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" \
        /etc/apache2/sites-available/*.conf \
        /etc/apache2/apache2.conf \
        /etc/apache2/conf-available/*.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && git config --global url."https://github.com/".insteadOf "git@github.com:" \
    && git config --global url."https://github.com/".insteadOf "ssh://git@github.com/" \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

COPY . /var/www/html

RUN set -eux; \
    set +x; \
    if [ -n "${GITHUB_TOKEN:-}" ]; then \
        COMPOSER_AUTH="$(printf '{"github-oauth":{"github.com":"%s"}}' "$GITHUB_TOKEN")"; \
        export COMPOSER_AUTH; \
    fi; \
    set -x; \
    attempt=1; \
    until [ "$attempt" -gt 5 ]; do \
        composer install \
            --no-dev \
            --prefer-dist \
            --no-interaction \
            --optimize-autoloader \
            --classmap-authoritative \
            --no-scripts \
            --no-progress \
        && break; \
        echo "Composer timeout, thu lai lan $attempt/5"; \
        attempt=$((attempt + 1)); \
        sleep 10; \
    done; \
    [ "$attempt" -le 5 ]; \
    unset COMPOSER_AUTH || true; \
    rm -rf /root/.composer/cache; \
    mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache; \
    chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

COPY docker/entrypoint.sh /usr/local/bin/winter-entrypoint
RUN chmod +x /usr/local/bin/winter-entrypoint
COPY docker/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/winter-entrypoint"]
