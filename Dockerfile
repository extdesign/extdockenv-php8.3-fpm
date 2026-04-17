ARG PHP_VERSION=8.3
ARG DEBIAN_FLAVOR=trixie

FROM php:${PHP_VERSION}-fpm-${DEBIAN_FLAVOR}

ARG APP_USER=www-data
ARG APP_UID=1000
ARG APP_GID=1000

ENV DEBIAN_FRONTEND=noninteractive

# Системные зависимости для сборки PHP-расширений и рантайма.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    unzip \
    pkg-config \
    libbz2-dev \
    libcurl4-openssl-dev \
    libfreetype6-dev \
    libicu-dev \
    libjpeg62-turbo-dev \
    libldap2-dev \
    libonig-dev \
    libpng-dev \
    libpq-dev \
    libpspell-dev \
    libxml2-dev \
    libzip-dev \
    zlib1g-dev \
    aspell \
    libmemcached-dev \
    libsasl2-dev \
    && rm -rf /var/lib/apt/lists/*

# Включаем "встроенные" расширения PHP (аналог части твоих apt-пакетов).
RUN set -eux; \
    docker-php-ext-configure gd --with-freetype --with-jpeg; \
    docker-php-ext-configure ldap; \
    docker-php-ext-install -j"$(nproc)" \
      bcmath \
      bz2 \
      curl \
      exif \
      gd \
      intl \
      ldap \
      mysqli \
      opcache \
      pdo_mysql \
      pspell \
      soap \
      xml \
      zip

# PECL-расширения: redis/apcu/memcached.
# memcache и mcrypt в PHP 8.3+ часто проблемные: ставим best-effort, без падения сборки.
RUN set -eux; \
pecl install redis apcu memcached; \
docker-php-ext-enable redis apcu memcached; \
(pecl install mcrypt && docker-php-ext-enable mcrypt) || echo "mcrypt build skipped"

# Небольшая настройка пользователя под volume из хоста.
RUN set -eux; \
    groupmod -o -g "${APP_GID}" "${APP_USER}" || true; \
    usermod -o -u "${APP_UID}" -g "${APP_GID}" "${APP_USER}" || true

RUN mkdir -p /var/log/php \
    && chown -R www-data:www-data /var/log/php

WORKDIR /var/www

COPY ./environment.ini /usr/local/etc/php/conf.d/90-environment.ini

EXPOSE 9000
CMD ["php-fpm"]
