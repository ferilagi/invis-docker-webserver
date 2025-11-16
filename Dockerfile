ARG TARGETPLATFORM
ARG BUILDPLATFORM

# node 24-alpine
FROM node:24-alpine AS nodejs
# php 8.4.14-fpm-alpine
FROM php:8.4.14-fpm-alpine

LABEL org.opencontainers.image.authors="Nahdammar(nahdammar@gmail.com)"
LABEL org.opencontainers.image.url="https://www.github.com/ferilagi"

# Mirror image alpineLinux
ARG APKMIRROR=dl-cdn.alpinelinux.org

USER root

WORKDIR /var/www/html

ENV TZ=Asia/Jakarta

# Php composer mirror: https://mirrors.cloud.tencent.com/composer/
ENV COMPOSERMIRROR="https://mirrors.cloud.tencent.com/composer/"

COPY --from=nodejs /opt /opt
COPY --from=nodejs /usr/local /usr/local

COPY conf/nginx.conf /etc/nginx/nginx.conf
COPY conf/nginx/default.conf /etc/nginx/conf.d/default.conf
COPY conf/supervisord.conf /etc/supervisord.conf
COPY conf/supervisor/* /etc/supervisor/conf.d/
COPY conf/ssl/* /etc/nginx/ssl/
# COPY conf/resolv.conf /etc/resolv.conf

COPY start.sh /start.sh

# Install PHP extensions dependencies FIRST
RUN apk add --no-cache \
    # Untuk LDAP & Authentication
    krb5-dev \
    openldap-dev \
    # Untuk GD Image
    libpng-dev \
    libwebp-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    # Untuk Database & XML
    libxml2-dev \
    postgresql-dev \
     # Untuk PHP extensions:
    linux-headers \
    rabbitmq-c-dev \
    zlib-dev \
    libmemcached-dev \
    cyrus-sasl-dev \
    # Untuk lainnya
    libzip-dev \
    curl-dev \
    icu-dev \
    oniguruma-dev

# Configure and install PHP extensions
RUN docker-php-ext-configure gd --with-freetype --with-jpeg --with-webp && \
    docker-php-ext-install \
        exif \
        sockets \
        gd \
        bcmath \
        intl \
        pcntl \
        soap \
        mysqli \
        pdo \
        pdo_mysql \
        pgsql \
        pdo_pgsql \
        zip \
        ldap \
        dom \
        opcache

# nginx-1.28.0 (gunakan versi stable, bukan 1.29.3)
ENV NGINX_VERSION=1.29.3
ENV NJS_VERSION=0.9.4
ENV PKG_RELEASE=1

RUN if [ "$APKMIRROR" != "dl-cdn.alpinelinux.org" ]; then sed -i 's/dl-cdn.alpinelinux.org/'$APKMIRROR'/g' /etc/apk/repositories; fi \
    && set -x \
    && apk update \
    && addgroup -g 101 -S nginx \
    && adduser -S -D -H -u 101 -h /var/cache/nginx -s /sbin/nologin -G nginx -g nginx nginx \
    && apkArch="$(cat /etc/apk/arch)" \
    && nginxPackages=" \
        nginx=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-xslt=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-geoip=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-image-filter=${NGINX_VERSION}-r${PKG_RELEASE} \
        nginx-module-njs=${NGINX_VERSION}.${NJS_VERSION}-r${PKG_RELEASE} \
    " \
    && case "$apkArch" in \
        x86_64|aarch64) \
            # Install langsung dari Alpine repo (skip complex key verification)
            apk add --no-cache $nginxPackages \
            ;; \
        *) \
            # Build dari source untuk architecture lain
            set -x \
            && tempDir="$(mktemp -d)" \
            && chown nobody:nobody $tempDir \
            && apk add --no-cache --virtual .build-deps \
                openssl-dev \
                pcre-dev \
                zlib-dev \
                libxslt-dev \
                gd-dev \
                geoip-dev \
                perl-dev \
                libedit-dev \
                mercurial \
                alpine-sdk \
            && su nobody -s /bin/sh -c " \
                export HOME=${tempDir} \
                && cd ${tempDir} \
                && hg clone https://hg.nginx.org/pkg-oss \
                && cd pkg-oss \
                && hg up ${NGINX_VERSION}-${PKG_RELEASE} \
                && cd alpine \
                && make all \
                && apk index -o ${tempDir}/packages/alpine/${apkArch}/APKINDEX.tar.gz ${tempDir}/packages/alpine/${apkArch}/*.apk \
                " \
            && apk add -X ${tempDir}/packages/alpine/ --no-cache $nginxPackages \
            ;; \
    esac \
    && if [ -n "$tempDir" ]; then rm -rf "$tempDir"; fi \
    && apk add --no-cache --virtual .gettext gettext \
    && mv /usr/bin/envsubst /tmp/ \
    && runDeps="$( \
        scanelf --needed --nobanner /tmp/envsubst \
            | awk '{ gsub(/,/, "\nso:", $2); print "so:" $2 }' \
            | sort -u \
            | xargs -r apk info --installed \
            | sort -u \
    )" \
    && apk add --no-cache $runDeps \
    && apk del .gettext \
    && mv /tmp/envsubst /usr/local/bin/ \
    && apk add --no-cache tzdata curl ca-certificates \
    && ln -sf /dev/stdout /var/log/nginx/access.log \
    && ln -sf /dev/stderr /var/log/nginx/error.log

ENV fpm_conf="/usr/local/etc/php-fpm.d/www.conf"
ENV php_vars="/usr/local/etc/php/conf.d/docker-vars.ini"

RUN echo "cgi.fix_pathinfo=0" > ${php_vars} &&\
    echo "upload_max_filesize = 100M"  >> ${php_vars} &&\
    echo "post_max_size = 100M"  >> ${php_vars} &&\
    echo "variables_order = \"EGPCS\""  >> ${php_vars} && \
    echo "memory_limit = 128M"  >> ${php_vars} && \
    sed -i \
        -e "s/;catch_workers_output\s*=\s*yes/catch_workers_output = yes/g" \
        -e "s/pm.max_children = 5/pm.max_children = 64/g" \
        -e "s/pm.start_servers = 2/pm.start_servers = 8/g" \
        -e "s/pm.min_spare_servers = 1/pm.min_spare_servers = 8/g" \
        -e "s/pm.max_spare_servers = 3/pm.max_spare_servers = 32/g" \
        -e "s/;pm.max_requests = 500/pm.max_requests = 800/g" \
        -e "s/user = www-data/user = nginx/g" \
        -e "s/group = www-data/group = nginx/g" \
        -e "s/;listen.mode = 0660/listen.mode = 0666/g" \
        -e "s/;listen.owner = www-data/listen.owner = nginx/g" \
        -e "s/;listen.group = www-data/listen.group = nginx/g" \
        -e "s/listen = 127.0.0.1:9000/listen = \/var\/run\/php-fpm.sock/g" \
        -e "s/^;clear_env = no$/clear_env = no/" \
        ${fpm_conf} \
    && cp /usr/local/etc/php/php.ini-production /usr/local/etc/php/php.ini

# Install Composer dan PECL extensions
RUN curl -sS http://getcomposer.org/installer | php -- --install-dir=/usr/bin/ --filename=composer \
    && apk add --no-cache \
        libstdc++ \
        mysql-client \
        bash \
        bash-completion \
        shadow \
        supervisor \
        git \
        zip \
        unzip \
        coreutils \
        libpng \
        libmemcached-libs \
        krb5-libs \
        icu-libs \
        icu \
        libzip \
        openldap-clients \
        postgresql-client \
        postgresql-libs \
        libcap \
        tzdata \
        sqlite \
        lua-resty-core \
        nginx-mod-http-lua \
        rabbitmq-c \
    && ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone \
    && apk add --no-cache --virtual .phpize-deps $PHPIZE_DEPS \
    && printf "\n\n" | pecl install amqp \
    && docker-php-ext-enable amqp \
    && printf "\n\n\n\n" | pecl install -o -f redis \
    && docker-php-ext-enable redis \
    && pecl install msgpack && docker-php-ext-enable msgpack \
    && pecl install igbinary && docker-php-ext-enable igbinary \
    && pecl install swoole && docker-php-ext-enable swoole \
    && printf "\n\n\n\n\n\n\n\n\n\n" | pecl install memcached \
    && docker-php-ext-enable memcached \
    && pecl install mongodb \
    && docker-php-ext-enable mongodb \
    && rm -rf /tmp/pear \
    && apk del .phpize-deps \
    && rm -rf /var/cache/apk/* /tmp/* /var/tmp/* \
    && rm -f /etc/nginx/conf.d/default.conf.apk-new /etc/nginx/nginx.conf.apk-new \
    && if [ "$APKMIRROR" != "dl-cdn.alpinelinux.org" ]; then sed -i 's/'$APKMIRROR'/dl-cdn.alpinelinux.org/g' /etc/apk/repositories; fi \
    && setcap 'cap_net_bind_service=+ep' /usr/local/bin/php \
    && mkdir -p /var/log/supervisor \
    && chmod +x /start.sh

EXPOSE 443 80

CMD ["/start.sh"]