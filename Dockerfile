# syntax=docker/dockerfile:1.7
#
# Runtime-only image: PHP-FPM + extensions + composer.
# The application code and vendor/ are NOT baked in - they are bind-mounted
# at /var/www/html (see docker-compose.yml / docker-compose.prod.yml).
ARG PHP_VERSION=8.5

FROM php:${PHP_VERSION}-fpm-alpine

# Match the host user so files written to the mounted code (storage/, vendor/)
# are not owned by root.
ARG UID=1000
ARG GID=1000

# opcache is built into PHP 8.5, so it is not installed as an extension.
RUN apk add --no-cache libzip oniguruma git unzip \
    && apk add --no-cache --virtual .build-deps $PHPIZE_DEPS libzip-dev oniguruma-dev \
    && docker-php-ext-install -j"$(nproc)" pdo_mysql zip bcmath pcntl \
    && apk del .build-deps \
    && addgroup -g "${GID}" app \
    && adduser -D -u "${UID}" -G app app

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY docker/php/opcache.ini /usr/local/etc/php/conf.d/opcache.ini
COPY docker/php/pool.conf /usr/local/etc/php-fpm.d/zz-pool.conf

WORKDIR /var/www/html
CMD ["php-fpm"]
