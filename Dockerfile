# initialize the PHP image
ARG PHP_IMG

# setup the PHP image
FROM "php:${PHP_IMG}"

# enable ssl
RUN a2enmod ssl

# restart apache
RUN service apache2 restart
