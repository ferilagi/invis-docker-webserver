# Stage 1: Node.js
FROM node:21.3.0-alpine3.18 AS nodejs

# Install Node.js dependencies if needed

# Stage 2: PHP and Nginx
FROM ferilagi/invis:latest

LABEL org.opencontainers.image.authors="Nahdammar(nahdammar@gmail.com)"
LABEL org.opencontainers.image.url="https://www.github.com/ferilagi"

# China alpine mirror: mirrors.ustc.edu.cn
ARG APKMIRROR=dl-cdn.alpinelinux.org

USER root

WORKDIR /var/www/html

# Npm mirror: https://registry.npmmirror.com
ENV NPMMIRROR=""

# Copy dependencies from the Node.js stage
COPY --from=nodejs /opt /opt
COPY --from=nodejs /usr/local /usr/local

# Copy the start.sh script
COPY start.sh /start.sh


EXPOSE 443 80

CMD ["/start.sh"]