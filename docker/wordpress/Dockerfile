FROM wordpress:latest

# Metadata
LABEL maintainer="WordPress DevOps Team"
LABEL description="Multi-environment WordPress image (dev/staging/prod) with Redis support"

# Allow build-time selection of environment: development, staging, production
ARG BUILD_ENV=development
ENV BUILD_ENV=${BUILD_ENV}
ENV DEBIAN_FRONTEND=noninteractive
ENV WORDPRESS_VERSION=${WORDPRESS_VERSION:-latest}

# Install build-time deps, libs and PHP extensions. Conditionally install dev tools when BUILD_ENV is dev or staging.
RUN set -eux; \
    apt-get update; \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libpng-dev \
        libjpeg-dev \
        libwebp-dev \
        libfreetype6-dev \
        libzip-dev \
        libicu-dev \
        zlib1g-dev \
        libxml2-dev \
        imagemagick \
        libmagickwand-dev \
        pkg-config \
        gcc \
        make \
        autoconf \
        unzip \
    ; \
    docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp; \
    docker-php-ext-install -j"$(nproc)" gd intl zip opcache; \
    # Optimize opcache for production
    echo "opcache.enable=1" >> /usr/local/etc/php/conf.d/opcache.ini; \
    echo "opcache.memory_consumption=256" >> /usr/local/etc/php/conf.d/opcache.ini; \
    echo "opcache.max_accelerated_files=10000" >> /usr/local/etc/php/conf.d/opcache.ini; \
    echo "opcache.revalidate_freq=60" >> /usr/local/etc/php/conf.d/opcache.ini; \
    echo "opcache.fast_shutdown=1" >> /usr/local/etc/php/conf.d/opcache.ini; \
    pecl install redis; \
    docker-php-ext-enable redis; \
    # Development-only helpers: composer, git, xdebug (kept for staging if desired)
    if [ "${BUILD_ENV}" = "development" ] || [ "${BUILD_ENV}" = "staging" ]; then \
        apt-get install -y --no-install-recommends git; \
        curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer; \
        if [ "${BUILD_ENV}" = "development" ]; then \
            pecl install xdebug || true; \
            docker-php-ext-enable xdebug || true; \
        fi; \
    fi; \
    # If production, remove build tools to slim image
    if [ "${BUILD_ENV}" = "production" ]; then \
        apt-get remove -y --purge gcc make autoconf pkg-config libmagickwand-dev unzip; \
        apt-get autoremove -y; \
    fi; \
    # Always cleanup apt cache and temporary files
    rm -rf /var/lib/apt/lists/* /tmp/pear /tmp/* /var/tmp/*; \
    true

# Set proper permissions for wordpress directory (www-data user)
RUN chown -R www-data:www-data /var/www/html && \
    find /var/www/html -type d -exec chmod 755 {} \; && \
    find /var/www/html -type f -exec chmod 644 {} \;

# Copy .htaccess template for nginx users (optional)
RUN if [ -f .htaccess.template ]; then cp .htaccess.template /var/www/html/; fi

WORKDIR /var/www/html

# Health check for WordPress
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=5 \
    CMD curl -f http://localhost/wp-admin/admin-ajax.php?action=heartbeat || exit 1

