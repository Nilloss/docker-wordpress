FROM alpine:3.19
LABEL Maintainer="Tim de Pater <code@trafex.nl>" \
  Description="Lightweight WordPress container with Nginx 1.24 & PHP-FPM 8.3 based on Alpine Linux."

# Install packages
RUN apk --no-cache add \
  php83 \
  php83-fpm \
  php83-mysqli \
  php83-json \
  php83-openssl \
  php83-curl \
  php83-zlib \
  php83-xml \
  php83-phar \
  php83-intl \
  php83-dom \
  php83-xmlreader \
  php83-xmlwriter \
  php83-exif \
  php83-fileinfo \
  php83-sodium \
  php83-gd \
  php83-simplexml \
  php83-ctype \
  php83-mbstring \
  php83-zip \
  php83-opcache \
  php83-iconv \
  php83-pecl-imagick \
  php83-session \
  php83-tokenizer \
  nginx \
  supervisor \
  curl \
  bash \
  less \
  nano \
  openssh \
  git


#---- SSH SETUP ----
# Set up SSH
RUN mkdir /var/run/sshd && \
    echo 'root:*cPG652$"O%`' | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    
# Generate SSH host keys
RUN ssh-keygen -A

# Expose SSH port
EXPOSE 22
#------------------

#---- DB SETUP ----
# Install MariaDB
RUN apk add --no-cache mariadb mariadb-client

RUN mkdir -p /var/lib/mysql
RUN chown -R mysql:mysql /var/lib/mysql

# Initialize MariaDB data directory
RUN mysql_install_db --user=mysql --datadir=/var/lib/mysql
#------------------

# Configure nginx
COPY config/nginx.conf /etc/nginx/nginx.conf

# Configure PHP-FPM
COPY config/fpm-pool.conf /etc/php83/php-fpm.d/zzz_custom.conf
COPY config/php.ini /etc/php83/conf.d/zzz_custom.ini

# Configure supervisord
COPY config/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# wp-content volume
VOLUME /var/www/wp-content
WORKDIR /var/www/wp-content
RUN chown -R nobody.nobody /var/www

# WordPress
ENV WORDPRESS_VERSION 6.4.3
ENV WORDPRESS_SHA1 ee3bc3a73ab3cfa535c46f111eb641b3467fa44e

RUN mkdir -p /usr/src

# Upstream tarballs include ./wordpress/ so this gives us /usr/src/wordpress
RUN curl -o wordpress.tar.gz -SL https://wordpress.org/wordpress-${WORDPRESS_VERSION}.tar.gz \
  && echo "$WORDPRESS_SHA1 *wordpress.tar.gz" | sha1sum -c - \
  && tar -xzf wordpress.tar.gz -C /usr/src/ \
  && rm wordpress.tar.gz \
  && chown -R nobody.nobody /usr/src/wordpress

# Create symlink for php
RUN ln -s /usr/bin/php83 /usr/bin/php

# Add WP CLI
RUN curl -o /usr/local/bin/wp https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
  && chmod +x /usr/local/bin/wp

# WP config
COPY wp-config.php /usr/src/wordpress
RUN chown nobody.nobody /usr/src/wordpress/wp-config.php && chmod 640 /usr/src/wordpress/wp-config.php

# Link wp-secrets to location on wp-content
RUN ln -s /var/www/wp-content/wp-secrets.php /usr/src/wordpress/wp-secrets.php

# Entrypoint to copy wp-content
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]

EXPOSE 80

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

HEALTHCHECK --timeout=10s CMD curl --silent --fail http://127.0.0.1/wp-login.php
