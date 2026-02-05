# WordPress with SSH, WP-CLI and optimized PHP limits
# For Coolify deployment
FROM wordpress:latest

# Install SSH server, WP-CLI and useful tools
RUN apt-get update && apt-get install -y \
    openssh-server \
    sudo \
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

# Create SSH directory and configure
RUN mkdir -p /var/run/sshd \
    && sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config \
    && sed -i 's/^#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && ssh-keygen -A

# PHP configuration with higher limits for MainWP/large sites
RUN echo "upload_max_filesize = 512M" > /usr/local/etc/php/conf.d/uploads.ini \
    && echo "post_max_size = 512M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "memory_limit = 512M" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_execution_time = 600" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_input_time = 600" >> /usr/local/etc/php/conf.d/uploads.ini \
    && echo "max_input_vars = 10000" >> /usr/local/etc/php/conf.d/uploads.ini

# Custom entrypoint that starts both Apache and SSH
COPY docker-entrypoint-ssh.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint-ssh.sh

# Expose both HTTP and SSH ports
EXPOSE 80 22

ENTRYPOINT ["docker-entrypoint-ssh.sh"]
CMD ["apache2-foreground"]
