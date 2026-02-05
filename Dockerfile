# WordPress with WP-CLI and optimized PHP limits for Coolify
# SSH dostępne przez docker exec lub Coolify Terminal
FROM wordpress:latest

# Install WP-CLI and useful tools
RUN apt-get update && apt-get install -y \
    less \
    vim \
    curl \
    wget \
    unzip \
    mariadb-client \
    && rm -rf /var/lib/apt/lists/*

# Install WP-CLI
RUN curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
    && chmod +x wp-cli.phar \
    && mv wp-cli.phar /usr/local/bin/wp

# PHP configuration with higher limits
RUN echo "upload_max_filesize = 512M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size = 512M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_execution_time = 600" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_input_time = 600" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_input_vars = 10000" >> /usr/local/etc/php/conf.d/uploads.ini

# Expose HTTP port
EXPOSE 80
