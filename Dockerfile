# setup Apache with PHP
FROM php:apache

# update the system
RUN apt-get update && apt-get upgrade -y

# enable ssl
RUN a2enmod ssl

# restart apache
RUN service apache2 restart
