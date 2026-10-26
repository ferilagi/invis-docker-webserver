FROM node:26.12.1-alpine3.23 AS nodejs

FROM ferilagi/webserver:php8.4.27

LABEL org.opencontainers.image.authors="Nahdammar(nahdammar@gmail.com)"
LABEL org.opencontainers.image.url="https://www.github.com/ferilagi/invis-docker-webserver"

# China alpine mirror: mirrors.ustc.edu.cn
ARG APKMIRROR=dl-cdn.alpinelinux.org

USER root

WORKDIR /var/www/html

# China npm mirror: https://registry.npmmirror.com
ENV NPMMIRROR=""

COPY --from=nodejs /opt /opt
COPY --from=nodejs /usr/local /usr/local

COPY start.sh /start.sh
RUN chmod +x /start.sh

EXPOSE 443 80

CMD ["/start.sh"]
