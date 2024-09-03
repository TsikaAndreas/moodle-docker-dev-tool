# Use environment variables
ARG MOODLE_DOCKER_PHP_VERSION

# Use the Moodle PHP Apache image as base
FROM moodlehq/moodle-php-apache:${MOODLE_DOCKER_PHP_VERSION}

# Install necessary packages for PHP and Node.js
RUN apt-get update && \
    apt-get install -y \
    curl \
    gnupg \
    nodejs \
    npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*


# Update PECL channel
RUN pecl channel-update pecl.php.net

# Check if Xdebug extension already exists and install the appropriate version
RUN if [ -z "$(find /usr/local/lib/php/extensions/ -name '*xdebug.so')" ]; then \
        echo "Xdebug extension not found. Installing..."; \
        PHP_VERSION=$(php -r 'echo PHP_VERSION;'); \
        if [ "${PHP_VERSION%%.*}" -lt "8" ]; then \
            pecl install xdebug-3.1.6; \
        else \
            pecl install xdebug; \
        fi && \
        docker-php-ext-enable xdebug && \
        echo "Xdebug installed and enabled."; \
    else \
        echo "Xdebug extension found. Skipping installation."; \
    fi

# Create Xdebug configuration file
RUN echo "zend_extension=$(find /usr/local/lib/php/extensions/ -name '*xdebug.so')" > /usr/local/etc/php/conf.d/docker-php-ext-xdebug.ini

# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Clean up
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Set working directory
WORKDIR /var/www/html