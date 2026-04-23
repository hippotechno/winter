# syntax=docker/dockerfile:1.7

ARG PHP_IMAGE=php:8.3-apache-bookworm
ARG BUILD_DATE=unknown
ARG VCS_REF=unknown

FROM ${PHP_IMAGE} AS php-base
ARG BUILD_DATE
ARG VCS_REF

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${VCS_REF}"

ENV APACHE_DOCUMENT_ROOT=/var/www/html \
    APP_ENV=production \
    APP_DEBUG=false \
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
    && pecl install redis \
    && docker-php-ext-enable redis \
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

FROM php-base AS deps
ARG PRUNE_DEV_ARTIFACTS=true

COPY artisan composer.json composer.lock index.php .htaccess /var/www/html/
COPY bootstrap /var/www/html/bootstrap
COPY config /var/www/html/config
COPY modules /var/www/html/modules
COPY plugins /var/www/html/plugins
COPY themes /var/www/html/themes

RUN --mount=type=secret,id=github_token,required=false set -eux; \
    set +x; \
    token=""; \
    if [ -f /run/secrets/github_token ] && [ -s /run/secrets/github_token ]; then \
        token="$(tr -d '\r\n' < /run/secrets/github_token)"; \
    fi; \
    if [ -n "$token" ]; then \
        composer config --global --auth github-oauth.github.com "$token"; \
    fi; \
    unset token; \
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
    if [ "$PRUNE_DEV_ARTIFACTS" = "true" ]; then \
        find /var/www/html/modules /var/www/html/plugins /var/www/html/themes /var/www/html/vendor \
            -type d \( -name .git -o -name .github -o -name .gitlab -o -name tests -o -name test -o -name __tests__ -o -name docs \) \
            -prune -exec rm -rf '{}' +; \
        find /var/www/html/modules /var/www/html/plugins /var/www/html/themes /var/www/html/vendor \
            -type f \( -name '*.map' -o -name '*.psd' -o -name '*.ai' -o -name '*.sketch' \) \
            -delete; \
    fi; \
    rm -f /root/.composer/auth.json; \
    rm -rf /root/.composer/cache

FROM ${PHP_IMAGE} AS runtime
ARG BUILD_DATE
ARG VCS_REF
ARG INCLUDE_SEED_ASSETS=false

LABEL org.opencontainers.image.created="${BUILD_DATE}" \
    org.opencontainers.image.revision="${VCS_REF}"

ENV APACHE_DOCUMENT_ROOT=/var/www/html \
    APP_ENV=production \
    APP_DEBUG=false

RUN printf 'Acquire::Retries "5";\nAcquire::ForceIPv4 "true";\n' > /etc/apt/apt.conf.d/99network \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        libzip4 \
        libicu72 \
        libpq5 \
        libonig5 \
        libxml2 \
        libpng16-16 \
        libjpeg62-turbo \
        libfreetype6 \
    && a2enmod rewrite headers \
    && sed -ri "s!/var/www/html!${APACHE_DOCUMENT_ROOT}!g" \
        /etc/apache2/sites-available/*.conf \
        /etc/apache2/apache2.conf \
        /etc/apache2/conf-available/*.conf \
    && echo "ServerName localhost" >> /etc/apache2/apache2.conf \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /var/www/html

COPY --from=deps /usr/local/lib/php/extensions /usr/local/lib/php/extensions
COPY --from=deps /usr/local/etc/php/conf.d /usr/local/etc/php/conf.d
COPY --chown=www-data:www-data --from=deps /var/www/html /var/www/html

RUN if [ "$INCLUDE_SEED_ASSETS" != "true" ]; then \
        find /var/www/html/plugins -mindepth 3 -maxdepth 3 -type d -name seed -prune -exec rm -rf '{}' +; \
    fi

RUN mkdir -p /var/www/html/storage /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

COPY docker/entrypoint.sh /usr/local/bin/winter-entrypoint
RUN chmod +x /usr/local/bin/winter-entrypoint

EXPOSE 80

ENTRYPOINT ["/usr/local/bin/winter-entrypoint"]

FROM runtime AS local

ENV XDEBUG_MODE=off \
    XDEBUG_START_WITH_REQUEST=trigger \
    XDEBUG_CLIENT_HOST=host.docker.internal \
    XDEBUG_CLIENT_PORT=9003 \
    XDEBUG_IDEKEY=VSCODE \
    XDEBUG_DISCOVER_CLIENT_HOST=0

RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends $PHPIZE_DEPS; \
    pecl install xdebug; \
    docker-php-ext-enable xdebug; \
    apt-get purge -y --auto-remove $PHPIZE_DEPS; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

COPY docker/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini
